module EventsHelper
  # Weekday and date of an event date, e.g. "Saturday, 21 November" or, for
  # dates spanning several days, "Fri 30 Oct – Sun 01 Nov"
  def event_date_days(event_date)
    start_date = event_date.start_date
    end_date = event_date.end_date

    if start_date.to_date == end_date.to_date
      l(start_date, format: '%A, %d %B')
    else
      "#{l(start_date, format: '%a %d %b')} – #{l(end_date, format: '%a %d %b')}"
    end
  end

  # Times of an event date, e.g. "12:00 – 22:00"
  def event_date_times(event_date)
    "#{l(event_date.start_date, format: '%H:%M')} – #{l(event_date.end_date, format: '%H:%M')}"
  end

  # A short relative label for dates that are happening now or soon, otherwise nil
  def event_date_badge(event_date)
    now = Time.zone.now

    if now.between?(event_date.start_date, event_date.end_date)
      _('Event|Happening now')
    elsif event_date.start_date.to_date == now.to_date
      _('Event|Today')
    elsif event_date.start_date.to_date == now.to_date.tomorrow
      _('Event|Tomorrow')
    end
  end

  # A short plain text teaser of the event description. The markdown is
  # rendered first, so that the truncation can't break its syntax.
  def event_excerpt(event, length: 250)
    # Entities like &amp; are decoded, as truncate escapes the text again
    text = CGI.unescapeHTML(strip_tags(Services::Markdown.render(event.description))).squish
    truncate(text, length: length, separator: ' ')
  end
end
