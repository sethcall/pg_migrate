require 'pg'
require 'pathname'
require 'digest/md5'


module PgMigrate

  attr_accessor :conn, :connection_hash, :manifest_path, :manifest

  class Migrator

    # possible connections (taken from pg documenttion)

    #host
    #
    #    server hostname
    #hostaddr
    #
    #    server address (avoids hostname lookup, overrides host)
    #port
    #
    #    server port number
    #dbname
    #
    #    connecting database name
    #user
    #
    #    login user name
    #password
    #
    #    login password
    #connect_timeout
    #
    #    maximum time to wait for connection to succeed
    #options
    #
    #    backend options
    #tty
    #
    #    (ignored in newer versions of PostgreSQL)
    #sslmode
    #
    #    (disable|allow|prefer|require)
    #krbsrvname
    #
    #    kerberos service name
    #gsslib
    #      .
    #    GSS library to use for GSSAPI authentication
    #service
    #
    #    service name to use for additional parameters
    def initialize(connection_hash)
      @connection_hash = connection_hash
      @manifest = nil
    end

    # the primary interface into this gem.
    # manifest_path = the directory containing your 'manifest' file, and you 'migrations' directory
    def migrate(manifest_path)
      @manifest_path = manifest_path

      @conn = PG::Connection.open(@connection_hash)
      @conn.exec("SET TRANSACTION SERIALIZABLE").clear

      process_manifest(@manifest_path)

      run_migrations(@manifest, @conn)
    end

    # run all necessary migrations
    def run_migrations(manifest)

      bootstrap_migration_table

      while true
        todo = pending_migrations(@manifest, read_executed())

        if todo.length == 0
          break
        end

        execute_migration(todo[0])
      end

    end

    # execute a single migration by loading it's statements from file, and then executing each
    def execute_migration(migration)
      statements = load_migration(migration.filepath)
      run_migration(statements)
    end

    # execute all the statements of a singel migration
    def run_migration(statements)
      statements.each do |statement|
        @conn.exec(statement).clear
      end
    end

    # determine which migrations stil need to be run
    def pending_migrations(manifest, executed)
      todo = []

      if executed.length > manifest.length
        raise 'the manifest declares less items than have already executed against this database instance. Likely old code deployed'
      end

      last_index = 0

      # loop through the manifest, and verify same indexed 'executed' is ok, and find what remains of the manifest todo
      manifest.each_with_index do |manifest_migration, index|
        if executed.length > index
          # compare executed and expected migration
          executed_migration = executed[index]
          # compare and make sure we are ok.
          if manifest_migration.name != executed_migration.name
            raise "#{manifest_migration.inspect} does not match existing migration: #{executed_migration.inspect}.  Perhaps you have branched the migrations and need to merge back in."
          end

          # TODO compare md5? production?
        else
          # we've found the end of our executed.  rip the rest of executed statements out
          last_index = index + 1
          break
        end
      end

      return manifest[last_index..manifest.length]
    end

    # dig out of the migration table all already-executed migrations
    def read_executed()
      executed = []
      result = @conn.exec("select name, ordinal, md5, created, production from pg_migrations order by ordinal")
      values = result.values
      values.each do |value|
        migration = Migration.new
        migration.name = value["name"]
        migration.ordinal = value["ordinal"]
        migration.md5 = value["md5"]
        migration.created = value["created"]
        migration.production = value["production"]
        executed.push(migration)
      end

      result.clear
      return executed
    end

  end

  # create our migrations table if it doesn't exist
  def bootstrap_migration_table()
    if !migration_table_exists?
      create_migration_table
    end

  end

  # lock the migration against anything.  useful when multiple migrators are running at the same time
  def lock_table
    @conn.exec("lock table pg_migrations in ACCESS EXCLUSIVE mode").clear
  end

  # does the migration table exist already?
  def migration_table_exists?
    result = @conn.exec("select table_name from information_schema.tables where table_name = 'pg_migrations")
    exists = result.count == 1
    result.clear
    return exists
  end

  # create the migration table sql statement executor
  def create_migration_table
    @conn.exec("create table pg_migrations (name varchar(255) primary key, ordinal integer not null, created timestamp default current_timestamp, md5 varchar(255) not null, production smallint default 1)").clear
  end

  # load the manifest's migration declarations, and validate that each migration points to a real file
  def process_manifest(manifest_path)
    @manifest = load_manifest(manifest_path)
    validate_migration_paths(manifest_path, @manifest)
  end

  # read in a migration file,
  # converting lines of text into SQL statements that can be executed with our database connection
  def load_migration(migration_path)
    statements = []

    current_statement = ""

    migration_lines = IO.readlines(migration_path)
    migration_lines.each_with_index do |line, index|
      line_stripped = line.strip

      if line_stripped.empty? || line_stripped.start_with?('--')
        # it's a comment; ignore
      else
        current_statement += " " + line_stripped;

        if line_stripped.end_with?(";")
          if current_statement =~ /^\s*CREATE\s+(OR\s+REPLACE\s+)?FUNCTION/i
            # if we are in a function, a ';' isn't enough to end.  We need to see if the last word was one of
            # pltcl, plperl, plpgsql, plpythonu, sql.
            # you can extend languages in postgresql; detecting these isn't supported yet.

            if current_statement =~ /(plpgsql|plperl|plpythonu|pltcl|sql)\s*;$/i
              statements.push(current_statement[0...-1]) # strip off last ;
              current_statement = ""
            end

          else
            statements.push(current_statement[0...-1]) # strip off last ;
            current_statement = ""
          end
        end
      end
    end

    if statements.length == 0
      raise 'no statements found in migration #{migration_path}'
    end

    return statements

  end

  # read in the manifest, saving each migration declaration in order as they are found
  def load_manifest(manifest_path)
    manifest = []
    manifest_filepath = File.join(manifest_path, "manifest")
    # there should be a file called 'manifest' at this location
    manifest_lines = IO.readlines(manifest_filepath)
    manifest_lines.each_with_index do |line, index|
      # ignore comments
      migration_name = line.strip
      if migration_name.empty? or migration_name.start_with?('#')
        # ignored!
      else
        manifest.push(Migration.new(migration_name, index, build_migration_path(manifest_path, migration_name)))
      end
    end

    return manifest
  end

  # verify that the migration files exist
  def validate_migration_paths(manifest_path, manifest)
    # each item in the manifest should be a valid file
    manifest.each do |item|
      item_path = build_migration_path(manifest_pat, item.name)
      if !Pathname.exist?
        raise "manifest reference #{item.name} does not exist at path #{item_path}"
      end
    end
  end

  # construct a migration file path location based on the manifest basedir and the name of the migration
  def build_migration_path(manifest_path, migration_name)
    File.join(manifest_path, "migrations", "#{migration_name}")
  end

end
