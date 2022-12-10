# MyJekyllBlog Database Schema

MyJekyllBlog uses [PostreSQL](https://www.postgresql.org/docs/13/) as its database and [DBIC](https://metacpan.org/pod/DBIx::Class) as its ORM.

## Update The Database Model

To update the database model, make your changes in `etc/schema.sql`.  Run `./bin/create-classes` to make the changes to the files in `lib/MJB/DB/Result/`.

Commit these changes.  Future installs will use this new model.

If you have a running instance, you will need to add the create table statements manually, and may need to make `alter table` statements.
