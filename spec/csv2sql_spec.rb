require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Csv2sql do
  context "basic tests" do
    it "cannot be null" do
      Csv2sql.new('foobar').should_not be_nil
    end
  end
  context "with a valid file" do
    before do
      @csv_file = File.join(File.dirname(__FILE__),"fixtures","gmclient.csv")
      @csv = Csv2sql.new(@csv_file)
    end
    it { File.exists? @csv_file }
    it { @csv.should_not be_nil }
    it { @csv.to_inserts.should_not be_nil }
    it { @csv.to_updates([nil,'balance'], :table=>'foobar').should_not be_nil }

  end
end
