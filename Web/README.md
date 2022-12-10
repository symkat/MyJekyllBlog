# MyJekyllBlog Web Application

## Technology

This application uses the [Mojolicious Framework](https://docs.mojolicious.org/).  [Minion](https://docs.mojolicious.org/Minion) 
is used as a job queue for long-running processes. **MJB::DB**, the database model found in `../DB/` uses the
[DBIx::Class](https://metacpan.org/pod/DBIx::Class) ORM and can be accessed from this application through `$c->db`.

## File & Directory Structure

| Name                   | Purpose                                                                                              |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| lib/MJB/Web.pm         | This is the library where the application startup happens.  It's where the magic happens.            |
| lib/MJB/Web/Command    | CLI commands that could be run by admins w/ shells -- see commands by running `./script/mjb --help`  |
| lib/mjb/Web/Controller | Contains controllers, all HTTP requests eventually end up here (or just rendering a template)        |
| lib/mjb/Web/Plugin     | Plugins can do a lot.  Mostly used here for interfacing more stand-alone libraries for use from mojo |
| lib/mjb/Web/Task       | Minion jobs, these are long-running code that can be handled by the builder or certbot servers       |
| mkits                  | Email templates, see [Email::MIME::Kit](https://metacpan.org/pod/Email::MIME::Kit) for more info     |
| public                 | Contains static assets that are hosted with the web application                                      |
| script                 | Contains scripts                                                                                     |
| templates              | The templates for the webapp. See [Mojo::Template](https://docs.mojolicious.org/Mojo/Template)       |
| cpanfile               | [CPAN Dependencies File](https://metacpan.org/dist/Module-CPANfile/view/lib/cpanfile.pod)            |
