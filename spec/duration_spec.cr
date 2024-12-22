require "./spec_helper"

require "../src/duration"

private def parse(string) : Time::Span
  Google::Duration.from_json(JSON::PullParser.new(string.to_json))
end

describe Google::Duration do
  it "parses seconds" do
    parse("3s").should eq 3.seconds
  end

  it "parses fractional seconds" do
    parse("3.5s").should eq 3.5.seconds
  end

  it "parses fractional seconds < 1" do
    parse("0.5s").should eq 0.5.seconds
  end

  it "parses minutes" do
    parse("3m").should eq 3.minutes
  end

  it "parses hours" do
    parse("3h").should eq 3.hours
  end

  it "parses hours, minutes, and seconds together" do
    parse("1h2m3.45s").should eq 1.hour + 2.minutes + 3.45.seconds
  end
end
