pg_migrate
==========

This project provides a simple and transparent schema migration tool. 

The primary drivers of the design of this project are as follows:
* Migrations are always defined in Postgresql SQL.  This means the developer and ops (even if the developers ARE ops) are always executing one of the most sensitive operations for any projects in similar contexts.
* When developing and testing, native code integration of the migrations is often more desirable than command-line oriented solutions.
** So, pg_migrate needs to exist in many languages to be compelling.  This is made possible by embedding virtually all logic in SQL templates that wrap your migration SQL, and relying on code to merely execute the resulting SQL.
** The first targeted languages are:
*** Ruby
*** Java
* When deploying the migrations to production environments, the command-line is ofter more desirable than code-integrated solutions.
* Abstractions away from raw SQL are a distraction when you have targeted Postgresql as your own database.
* Once you embrace `CREATE FUNCTION`, even complex migrations are readily possible in SQL.
* A terse, single file describing the order of migrations is simple (perhaps too simple, eventually), but allows you to focus on your overall set of migrations.
* A build step converts your migrations from your SQL to lightly templated versions of your SQL, and also gives pg_migrate a chance to run any tests you have defined against each migration in isolation. 
* Down migrations are important, and will be supported shortly.
