require 'spec_helper'

describe Migrator do
  it "load single manifest" do
    migrator = Migrator.new({})
    manifest = migrator.load_manifest("spec/pg_migrate/manifests/single")

    manifest.length.should == 1
    manifest[0].should == "single_migrations/single1.sql"
  end

  it "fail on bad manifest reference" do
    migrator = Migrator.new({})
    expect { migrator.validate_manifest('absolutely_nowhere_real', ["migration1.sql"]) }.to raise_exception
  end

end