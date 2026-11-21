class MenuItem < ApplicationRecord
  # == Attributes ==================================================================
  enum :location, {
    navbar: 'navbar',
    footer: 'footer'
  }, default: :navbar, validate: true

  # == Constants ===================================================================
  TYPES = %w[MenuLinkItem MenuDropdownItem].freeze

  # == Associations ================================================================
  belongs_to :page, optional: true, inverse_of: :menu_items

  # == Validations =================================================================
  validates :sort, numericality: { greater_than_or_equal_to: 0, less_than: MAX_PERMITTED_INT, integer_only: true }, presence: true
  validates_boolean :visible
  validates :title, presence: true, length: { maximum: 255 }
  validates :type, inclusion: TYPES

  # == Hooks =======================================================================

  # == Scopes ======================================================================

  # == Class Methods ===============================================================
  def self.human_location(location)
    _("MenuItem|location|#{location}")
  end

  def self.location_options
    locations.keys.map { |location| [human_location(location), location] }
  end

  # == Instance Methods ============================================================
  # == Private Methods =============================================================
end
