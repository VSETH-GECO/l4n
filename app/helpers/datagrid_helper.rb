module DatagridHelper
  # HTML attributes for a datagrid header or body cell. Replaces
  # `datagrid_column_classes`, which was deprecated in datagrid 2.
  def datagrid_cell_attributes(grid, column)
    {
      **column.tag_options,
      class: class_names(
        column.name,
        column.tag_options[:class],
        'datagrid-order-active-asc'  => grid.ordered_by?(column, false),
        'datagrid-order-active-desc' => grid.ordered_by?(column, true)
      ),
      data:  { column: column.name }
    }
  end
end
