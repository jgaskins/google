require "../spec_helper"
require "../../src/calendar"

describe Google::Calendar::V3::Timestamp do
  described_class = Google::Calendar::V3::Timestamp

  it "converts from a fixed offset to a time" do
    ts = described_class.new(
      date_time: Time::Format::RFC_3339.parse("2023-07-05T12:34:56.789123Z"),
      time_zone: "GMT-04:00",
    )

    ts.to_time.should eq Time::Format::RFC_3339.parse("2023-07-05T08:34:56.789123-04:00")
  end

  it "converts from a dynamic offset to a time in DST" do
    ts = described_class.new(
      date_time: Time::Format::RFC_3339.parse("2023-07-05T12:34:56.789123Z"),
      time_zone: "America/New_York",
    )

    ts.to_time.should eq Time::Format::RFC_3339.parse("2023-07-05T08:34:56.789123-04:00")
  end

  it "converts from a dynamic offset to a time" do
    ts = described_class.new(
      date_time: Time::Format::RFC_3339.parse("2023-01-05T12:34:56.789123Z"),
      time_zone: "America/New_York",
    )

    ts.to_time.should eq Time::Format::RFC_3339.parse("2023-01-05T07:34:56.789123-05:00")
  end
end
