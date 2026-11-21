module Queries::Event
  class FetchPastEvents < Inquery::Query
    def call
      # Fetch events where all dates have ended, ordered by their last date
      rel = Event.all

      rel = rel.joins(ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, { now: Time.zone.now }]))
        INNER JOIN (
          SELECT DISTINCT ON (event_id) * FROM event_dates
          WHERE event_id NOT IN (
            SELECT event_id
            FROM event_dates
            WHERE event_dates.end_date >= :now
          )
          ORDER BY event_id, start_date DESC
        ) AS event_dates_grouped
        ON events.id = event_dates_grouped.event_id
      SQL

      rel.order('event_dates_grouped.start_date DESC')
    end
  end
end
