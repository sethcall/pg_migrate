pg_migrate
==========

This project provides a simple and transparent schema migration tool. 

The primary drivers of the design of this project are as follows:

Migrations in SQL
-----------------

Migrations are always defined in Postgresql SQL.  This means the developer and ops (or devops) are always executing one of the most sensitive operations for any projects in similar contexts.

Native Code Integration
-----------------------
When developing and testing, native code integration of the migrations is often more desirable than command-line oriented solutions.  So, pg_migrate needs to exist in many languages to be compelling.  This is made possible by embedding virtually all logic in SQL templates that wrap your migration SQL, and relying on code to merely execute the resulting SQL.
* So far, only *ruby* is supported.

Command-Line Integration
------------------------
When deploying the migrations to production environments, the command-line is ofter more desirable than code-integrated solutions.
* The first targeted 'command-line' is PSQL.  Any migration should run with `psql -f migration.sql`.

No SQL abstractions
-------------------
Abstractions away from raw SQL are a distraction when you have targeted Postgresql as your own database, and come with their own learning curve.   Learning SQL well is hard enough.
* Once you embrace `CREATE FUNCTION`, even complex migrations are readily possible in SQL.

Linear Manifest
---------------
A terse, single file describing the order of migrations is straightforward, and allows you to focus on your overall set of migrations.

Build & Validation Step
-----------------------
The build step protects your SQL migrations with a  TRANSACTION wrapper and idempotency guarantees, and also gives pg_migrate a chance to run any tests you have defined against each migration in isolation. 
* Test execution during the the build is not yet implemented.

Rollbacks (Down migrations)
---------------------------
Down migrations are important, and will be supported shortly.

Mistake Proof (Idempotency)
---------------------------
Each file that results from the build step should be 'mistake proof', in that someone trying to manually migrate can accidentally run the wrong migration (either because it's already been run or isn't the next logical migration to run), and pg_migrate will reject it.

