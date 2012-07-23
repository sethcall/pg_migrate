pg_migrate
==========

This project provides a simple and transparent schema migration tool, that strives to make all parties involved with the database happy.

At a Glance
-----------

This section is a quick tour to give you feel for the nature of this project:

## Install pg_migrate 
```bash
# if you are into ruby
gem install pg_migrate

# if you like java
#todo
```

## Create a pg_migrate project
Create a project that defines your manifest.
```bash
mkdir my_corp_schemas
# create your pg_migrate
touch my_corp_schemas/manifest

# create the 'up' directory. (contains forward migrations)
mkdir my_corp_schemas/up
# create your first migration file 
touch my_corp_schemas/up/first.sql 
```


```
-- first.sql
create table users(id BIGSERIAL PRIMARY KEY);    
```

## Build your migration manifest
Build your migration project so that pg_migrate can protect your migrations above with transactions and other guards.  The output of this 'build' process will look a lot like the input.

```bash
# build output
mkdir target 
pg_migrate build --source my_corp_schemas --out target/my_corp_schemas

ls target/my_corp_schemas
> manifest
> up/all.sql # a concatenation of all bootstrap.sql and first.sql (and other 'up' migrations, if you had them)
> up/bootstrap.sql # creates pg_migrate tables and validation FUNCTIONs
> up/first.sql # transaction wrapped & validations added to your SQL

# build an executable jar containing your manifests
pg_migrate_java package --name com.mycorp.MyCorpSchemas --version 1.0 --source target/my_corp_schemas --out target

# build an executable gem containing your manifests
pg_migrate_ruby package --name my_corp_schemas --version 1.0.0 --source target/my_corp_schemas --out target

# tar up the schemas for manual usage
tar -xvzf my_corp_schemas.tar.gz target/my_corp_schemas
```

## Add a dependency to your pg_migrate package
You have now freed all of your projects to depend on the same version of the database, in any language supported by pg_migrate.

```xml
<!-- maven example -->
<dependency>
    <groupId>com.my_corp</groupId>
    <artifactId>my_corp_schemas</artifacteId>
    <version>1.0</version>
</dependency>
```

``` ruby
source 'https://rubygems.org'
source 'http://gems.my_corp.org'

gem 'my_cormp_schemas', '1.0.0'
```

## Migrate in code
```java
import com.mycorp.MyCorpSchemas.Migrator

class MyCorpApp {
    
    public MyCorpApp() {
        Connection conn = makeJdbcConnection();

        new Migrator().migrate(conn);

        success();
    }
}

```

```ruby
require 'my_corp_schemas'

class MyCorpApp 
    def initialize
        Migrator.new(:pgconn=>conn).migrate
    end
end
```

## Migrate it from psql (command-line #1)
```bash
wget http://my_corp.com/my_corp_schemas.tar.gz
tar -cvzf my_corp_schemas.tar.gz
# attempt to migrate all migrations (safe even if run before)
psql -f target/my_corp_schemas/up/all.sql my_corp_db
# attempt to migrate just one migration (because you are certain you know the next one in line)
# if you really did these psql attempts in this order, 
# the 1st one would succeed (bootstrapping pg_migrate and running first.sql), and this next psql attempt would cause no change to the database.
psql -f target/my_corp_schemas/up/first.sql my_corp_db
```

## Migrate it using pg_migrate (command-line #2)
```bash
gem install pg_migrate # you could have used the java vesion of pg_migrate
wget http://my_corp.com/my_corp_schemas.tar.gz
tar -cvzf my_corp_schemas.tar.gz
pg_migrate up --source target/my_corp_schemas --connopts "dbname:my_corp_db user:postgres password:postgres host:localhost" 
```

The primary drivers of the design of this project are as follows:

Design: Natural Support for the Phases of Software Development
----------------------------------------------------------
This is the major reason this project exists.  No tool correctly satisfies this requirement.  
What is meant by *Natural Support*?  Natural support implies that the tool offers a means of usage that fits with the common-case expectations of that class of user at that time.  Developers expect language support.  Operations expects code support.  And sometimes vice-versa. 

 So what are the phases?
* Test
* Development
* Deployment to Staging Environment
* Deployment to Production

### Phase: Test
In tests of an application that uses a database, it is most desirable to have a native language mechanism to cause a 'up' schema migration at the start of the test suite or test instance. For instance, in a Ruby rspec test:

```ruby
    before(:all) do
        # let's make sure we have a clean database before the test runs
        drop_and_create_database()
        # now, apply our schema migrations
        run_up_migrations()
    end
```

Or perhaps in a Java TestNG test:

```java
    @BeforeTest
    public void beforeTest() {
        // make sure we have a clean database before the test runs
        dropAndCreateDatabase()
        // now, apply our schema migrations
        runUpMigrations()    
    }
```

The approach shown in these examples ensures that the database is correct and up-to-date before the test runs.  Allowing the test harness to completely set up a correct test environment minimizes confusion and headaches.

However, with any existing tool (that I've seen), the focus is on the command-line experience, or at most, language support for just one language.  An example:  if you using a top-notch migration tool like [SQL Alchemy](http://www.sqlalchemy.org/), but you aren't using Python... then you need to make sure you have Python installed, and the SQL Alchemy package installed in that version of Python.  You have to make sure that happens on every developer machine and the build server, at a minimum.

As many developers would agree, it's much more desirable to only require a library; not require an entire toolchain that may or may not be comfortable to all developers on the team.  This keeps the environment setup down to a minimum.   Also, versioning a library is usually a process that a developer understands much more comfortably then somehow enforcing that the correct version of your migration tool is installed.

### Phase: Development
#### Competing Usage Patterns
During development, there are two competing migration patterns.  
##### Manual, Command-Line Migrations
One is to expect the developer to know when they must migrate their development database.  An example is the common way many use the Rails `rake db:migrate`... manually, at the command-line. 
##### Automatic Migrations on software startup
 The other pattern is to code into your application the schema migration process on startup, so that the application is guaranteed to have a correct database (much like the test usecase). 

Compared to the _Test_ phase, these patterns show two fundamentally different requirements; a reasonable command-line experience as well as native code integration.  
#### Small Projects vs Monolithic
With DVCS such as Git and Mercurial, technologies such as Maven, Ivy, and Gemfiles providing excellent dependency management, and so many powerful but different languages to choose from, it's becoming less desirable or practical to have monolithic projects.  For instance, even though Rails is a fanstastic web development framework, that doesn't mean it makes sense for you to do all development in Ruby.  Say then you have both a Rails app and Java application listening on a message queue, with the Java application performing long-running tasks on the behalf of the Rails app.  Further, let's say both apps want access to the same database.  Ideally, then, your database migrations are in a common, shared repository to both of these applications. 

##### Schemas as Common Dependencies
pg_migrate is completely compatible with this style of 'numerous, small project' development.  It does this by supporting multiple languages easily, and by supporting the concept of code bundling of the manifest.  (i.e, an important feature is to allow a single 'pg_migrate manifest' project to readily generate a .jar, .gem, or whatever other code artifacting mechanism exists to allow your 'leaf projects' (the Rails app and Java app, in this example) a way to simply depend on a library that represents their schema, rather than define it themselves.
   
### Phase: Deployment to Staging Environment
If you ascribe to the principles of automation (such as [DevOps](http://en.wikipedia.org/wiki/DevOps)), ideally the migration of the database occurs automatically.  Still, the database can present a challenge.  Should the software migrate the database, when it starts?  But what if there are multiple instances of the same software--won't the migrations possible occur at the same time and cause chaos?  Or what if there are multiple but separate components that both refer to the same database?   It's hard not to be concerned that there are too many cooks in the kitchen, if you let each and every piece of software attempt a schema migration.  Ok, what if instead the migrations be executed as a stand-alone process in a two-staged approach, first migrate the database, then update and run the software.   That provides absolute control, but if your staging environment is comprised of multiple server instances, this may be more readily said that done.

All of these are valid approaches, and frankly, if you actually have a staging environment, you probably have enough to worry about.  So, all options should be open to you.  Flexibility is power.

So, pg_migrate supports these use cases regardless if you are using pg_migrate from the command-line, or via code integration:
#### Migrations are idempotent
Multiple attempts at the same migration are safe to do.
#### Migrations attempts can occur concurrently
No matter how many clients are trying to migrate the database, migrations are safe.  This is made possibly by use of an exclusive lock on the pg_migrations table during migrations, and a purposeful lack of state between individual migration steps in the overall migration.
#### A migration attempt using an old build of your migrations will fail.  
Unless you deliberately ignore the return code or exception thrown, this should cause your software to fail.  Ultimately, a fail-fast mentality is most sensible in the face of unknown database state.

A short example.  With these capabilities, one can use Puppet in a simple way, and have 'eventual stability', even in a multiple node staging deployment.  In other words, say every piece of software is allowed to migrate the database on startup, and say that you update all your software in Puppet.  Over the course of 30 minutes (assuming the default Puppet sync interval), all of your software should have updated, and the 1st one to have updated would have updated the database.  While it's true for 30 minutes some of your software may have been 'upset', once they update and expect the new schema, all is well again.  This level of imperfection is often suitable for a staging environment, where the act of updating should be easy and hands-off, even if it means it will take a while for the environment to become stable. 


### Phase: Deployment to Production
Many of the points made in the staging environment are valid here, as well.   But let's assume your production has a 0-downtime requirement (or at least, very very short).  Or if it's not a requirement in your environment, you may still consider it a laudable goal anyway. 

In this situation, updates to the database are often considered manual-only.  No software should be allowed to update the database; it's just too sensitive of an operation to not have a console open and watching all that transpires.  To that end, pg_migrate follows a few principles to help:

* The SQL executed by psql or by code is same (ok: very, very minor differences).  This means even if next migration intended for production has only be executed via code, it simply shouldn't matter; it's the same SQL being processed in any phase.  
* Every file, if run as a complete file from `psql -f`, is safe to run.  Specifically, an already-run migration file will not attempt to process anything. A migration that's not next in-line (say there are two migration steps, and you accidentally chose the last one to run) will also not process anything.  Finally, there is a 'all-in-one' migration file generated, that you can blindly pass to psql.  Using this file is no different than executing each migration one-by-one.  While wasteful in the sense that already-run migrations will be ignored, it's also simple and safe. 

Migrations in SQL
-----------------

Migrations are always defined in Postgresql SQL.  This means the developer and ops (or devops) are always executing one of the most sensitive operations for any projects in similar contexts.

Native Code Integration
-----------------------
When developing and testing, native code integration of the migrations is often more desirable than command-line oriented solutions.  So, pg_migrate needs to exist in many languages to be compelling.  This is made possible by embedding virtually all logic in SQL templates that wrap your migration SQL, and relying on code to merely execute the resulting SQL.
* [pg_migrate ruby](https://github.com/sethcall/pg_migrate_ruby)
* [pg_migrate java](https://github.com/sethcall/pg_migrate_java) (not yet released)

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

