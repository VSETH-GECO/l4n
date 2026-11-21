module Queries::MenuItem
  class FindActiveTopElements < Inquery::Query
    schema3 do
      str! :location, enum: ::MenuItem.locations.keys
    end

    def call
      ::MenuItem.where(parent_id: nil, location: osparams.location).order(sort: :asc)
    end
  end
end
