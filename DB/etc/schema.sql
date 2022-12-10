CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE person (
    id                          serial          PRIMARY KEY,
    name                        text            not null,
    email                       citext          not null unique,
    is_enabled                  boolean         not null default true,
    is_admin                    boolean         not null default false,
    created_at                  timestamptz     not null default current_timestamp
);

-- For stripe subscriptions
CREATE TABLE subscription (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null unique references person(id),
    stripe_customer_id          text            ,
    is_valid                    boolean         not null default false,
    last_checked_at             timestamptz     not null default current_timestamp,
    created_at                  timestamptz     not null default current_timestamp
);

-- Allow notes to be made about a person (Admin Panel -> People -> Person)
CREATE TABLE person_note (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    source_id                   int             not null references person(id),
    content                     text            ,
    created_at                  timestamptz     not null default current_timestamp
);

-- Settings for a given user.  | Use with care, add things to the data model when you should.
CREATE TABLE person_settings (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    name                        text            not null,
    value                       json            not null default '{}',
    created_at                  timestamptz     not null default current_timestamp,

    -- Allow ->find_or_new_related()
    CONSTRAINT unq_person_id_name UNIQUE(person_id, name)
);

CREATE TABLE auth_password (
    person_id                   int             not null unique references person(id),
    password                    text            not null,
    salt                        text            not null,
    updated_at                  timestamptz     not null default current_timestamp,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE auth_token (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    scope                       text            not null,
    token                       text            not null,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE domain (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    name                        citext          not null unique,
    ssl                         text            default null,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE blog (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    domain_id                   int             references domain(id),

    -- Settings: File Allowances
    max_static_file_count       int             not null default 100,
    max_static_file_size        int             not null default   5, -- MiB
    max_static_webroot_size     int             not null default  50, -- MiB

    -- Settings: Build Timers
    minutes_wait_after_build    int             not null default 10,
    builds_per_hour             int             not null default  3,
    builds_per_day              int             not null default 12,

    -- Settings: Features
    build_priority              int             not null default 1,

    is_enabled                  boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE ssh_key (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    title                       text            ,
    public_key                  text            not null,
    private_key                 text            not null,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE basic_auth (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    username                    text            not null,
    password                    text            not null,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE repo (
    id                          serial          PRIMARY KEY,
    blog_id                     int             references blog(id),
    url                         text            not null,

    -- Auth methods for the url.
    basic_auth_id               int             references basic_auth(id),
    ssh_key_id                  int             references ssh_key(id),

    created_at                  timestamptz     not null default current_timestamp
);

-- For jobs that should show up on the web interface in Blog Manager -> Jobs.
CREATE TABLE job (
    id                          serial          PRIMARY KEY,
    blog_id                     int             not null references blog(id),
    minion_job_id               int             not null, -- For minion->job($id)
    created_at                  timestamptz     not null default current_timestamp
);

-- For jobs that should show up on the web interface in Admin Panel -> Jobs.
CREATE TABLE admin_job (
    id                          serial          PRIMARY KEY,
    minion_job_id               int             not null, -- For minion->job($id)
    created_at                  timestamptz     not null default current_timestamp
);

-- The domains that a user can host their blog under.
CREATE TABLE hosted_domain (
    id                          serial          PRIMARY KEY,
    name                        text            not null,
    letsencrypt_challenge       text            not null default 'http', -- http or dns
    letsencrypt_dns_auth        json            not null default '{}',
    created_at                  timestamptz     not null default current_timestamp
);


-- Make a simple invite gate for creating accounts.
CREATE TABLE invite (
    id                          serial          PRIMARY KEY,
    code                        text            not null,
    is_active                   boolean         not null default true,
    is_one_time_use             boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

-- Servers that we will deploy the blogs to.
CREATE TABLE server (
    id                          serial          PRIMARY KEY,
    hostname                    text            not null,
    created_at                  timestamptz     not null default current_timestamp
);

-- Allow notes to be made that will show up on the admin panel.
--
-- The is_read count can help with adding a marker to the Admin Panel -> Notes tab
-- when there is unread notes.
CREATE TABLE system_note (
    id                          serial          PRIMARY KEY,
    is_read                     boolean         not null default false,
    source                      text            ,
    content                     text            ,
    created_at                  timestamptz     not null default current_timestamp
);
