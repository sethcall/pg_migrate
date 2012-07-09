require 'spec_helper'

describe Migrator do
  it "load single manifest" do
    migrator = Migrator.new({})
    manifest = migrator.load_manifest("spec/pg_migrate/manifests/single_manifest")

    manifest.length.should == 1
    manifest[0].name.should == "single1.sql"
  end

  it "load single migration" do
    migrator = Migrator.new({})
    migrations = migrator.load_migration("spec/pg_migrate/manifests/single_manifest/migrations/single1.sql")

    migrations.length.should == 8
    migrations[0] = "select 1"
    migrations[1] = "select 2"
    migrations[2] = "select 3"
    migrations[3] = "create table emp()"
    migrations[4] = "CREATE FUNCTION clean_emp() RETURNS void AS ' DELETE FROM emp; ' LANGUAGE SQL"
    migrations[5] = "CREATE FUNCTION clean_emp2() RETURNS void AS 'DELETE FROM emp;' LANGUAGE SQL"
    migrations[6] = "CREATE LANGUAGE plpgsql"
    migrations[7] = "CREATE FUNCTION populate() RETURNS integer AS $$ DECLARE BEGIN PERFORM select 1; END; $$ LANGUAGE plpgsql"
  end

  it "run single migration" do
    config = ConfigParser.rails("spec/database.yml", "test")
  end
  
  it "fail on bad manifest reference" do
    migrator = Migrator.new({})
    expect { migrator.validate_migration_paths('absolutely_nowhere_real', ["migration1"]) }.to raise_exception
  end



end