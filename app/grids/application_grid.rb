module Grids
  class ApplicationGrid < Datagrid::Base
    def self.model(model_class = nil)
      return @model unless model_class

      @model = model_class
    end

    def self.pagination_param(pagination_param_name = nil)
      return @pagination_param unless pagination_param_name

      @pagination_param = pagination_param_name
    end

    def self.humanize_enum_for_select(klass, enum_name, enum_entry)
      _("#{klass.name}|#{enum_name}|#{enum_entry}")
    end

    # Datagrid 2 serializes filter values with `as_json`, which would put all
    # attributes of record-valued filters (e.g. `lan_party`) into the ordering
    # links. Serialize records to their id instead, as datagrid 1 did.
    def as_query
      records = attributes.select { |_name, value| value.is_a?(::ActiveRecord::Base) }
      super.merge(records.to_h { |name, record| [name.to_s, record.to_param] })
    end
  end
end
