module Operations::Admin::MenuItem
  class Index < RailsOps::Operation
    schema3 {} # No params allowed for now

    policy :on_init do
      authorize! :manage, MenuItem
    end

    def top_items(location)
      ::MenuItem.where(parent_id: nil, location: location).order(:sort)
    end
  end
end
