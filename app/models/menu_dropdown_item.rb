class MenuDropdownItem < MenuItem
  # == Attributes ==================================================================

  # == Constants ===================================================================

  # == Associations ================================================================
  has_many :children, class_name: 'MenuLinkItem', foreign_key: 'parent_id', dependent: :destroy, inverse_of: :parent

  # == Validations =================================================================
  validates :parent_id, absence: true
  validate :only_in_navbar

  # == Hooks =======================================================================

  # == Scopes ======================================================================

  # == Class Methods ===============================================================

  # == Instance Methods ============================================================

  # == Private Methods =============================================================
  private

  def only_in_navbar
    errors.add(:location, _('MenuDropdownItem|Dropdowns can only be placed in the top navigation')) unless navbar?
  end
end
