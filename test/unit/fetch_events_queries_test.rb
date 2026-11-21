require 'test_helper'

module Unit
  class FetchEventsQueriesTest < ApplicationTest
    def test_date_that_ended_earlier_today_is_past
      travel_to Time.zone.local(2026, 11, 21, 22, 30) do
        ended_today = create_event('Ended today', [[Time.zone.local(2026, 11, 21, 12), Time.zone.local(2026, 11, 21, 22)]])
        happening = create_event('Happening', [[Time.zone.local(2026, 11, 21, 20), Time.zone.local(2026, 11, 21, 23)]])

        assert_equal [happening], ::Queries::Event::FetchFutureEvents.run.to_a
        assert_equal [ended_today], ::Queries::Event::FetchPastEvents.run.to_a
      end
    end

    def test_next_date_skips_date_that_ended_today
      travel_to Time.zone.local(2026, 11, 21, 22, 30) do
        event = create_event('BGD', [
                               [Time.zone.local(2026, 11, 21, 12), Time.zone.local(2026, 11, 21, 22)],
                               [Time.zone.local(2026, 11, 22, 12), Time.zone.local(2026, 11, 22, 22)]
                             ])

        assert_equal Time.zone.local(2026, 11, 22, 12), event.next_date.start_date
        assert_equal Time.zone.local(2026, 11, 21, 22), event.last_date.end_date
        assert_equal [event], ::Queries::Event::FetchFutureEvents.run.to_a
        assert_empty ::Queries::Event::FetchPastEvents.run.to_a
      end
    end

    private

    def create_event(title, dates)
      ::Event.create!(
        title:                  title,
        event_dates_attributes: dates.map { |start_date, end_date| { start_date: start_date, end_date: end_date } }
      )
    end
  end
end
