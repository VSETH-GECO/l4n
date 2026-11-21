module Queries::Event
  class FetchFutureEvents < Inquery::Query
    def call
      # Fetch events with at least one date that hasn't ended yet, i.e. that
      # is upcoming or currently happening, ordered by their next date
      rel = Event.all

      rel = rel.joins(ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, { now: Time.zone.now }]))
        INNER JOIN (
          SELECT DISTINCT ON (event_id) *
          FROM event_dates
          WHERE event_dates.end_date >= :now
          ORDER BY event_id, start_date ASC
        ) AS event_dates_grouped
        ON events.id = event_dates_grouped.event_id
      SQL

      rel.order('event_dates_grouped.start_date ASC')
    end
  end
end
