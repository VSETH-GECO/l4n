require 'test_helper'

class EventsHelperTest < ActionView::TestCase
  def test_event_date_days_on_a_single_day
    date = event_date('2026-11-21 12:00', '2026-11-21 22:00')

    assert_equal 'Saturday, 21 November', event_date_days(date)
  end

  def test_event_date_days_over_several_days
    date = event_date('2026-10-30 12:00', '2026-11-01 16:00')

    assert_equal 'Fri 30 Oct – Sun 01 Nov', event_date_days(date)
  end

  def test_event_date_times
    assert_equal '12:00 – 22:00', event_date_times(event_date('2026-11-21 12:00', '2026-11-21 22:00'))
  end

  def test_event_date_badge
    travel_to Time.zone.parse('2026-11-21 10:00') do
      assert_equal 'Today', event_date_badge(event_date('2026-11-21 12:00', '2026-11-21 22:00'))
      assert_equal 'Happening now', event_date_badge(event_date('2026-11-21 09:00', '2026-11-21 22:00'))
      assert_equal 'Happening now', event_date_badge(event_date('2026-11-20 12:00', '2026-11-22 16:00'))
      assert_equal 'Tomorrow', event_date_badge(event_date('2026-11-22 12:00', '2026-11-22 22:00'))
      assert_nil event_date_badge(event_date('2026-11-25 12:00', '2026-11-25 22:00'))
    end
  end

  private

  def event_date(start_date, end_date)
    EventDate.new(start_date: Time.zone.parse(start_date), end_date: Time.zone.parse(end_date))
  end
end
