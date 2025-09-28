# frozen_string_literal: true

class Flower < ApplicationRecord
  validates :color, presence: true
  validates :number_of_petals, presence: true, numericality: { only_integer: true, greater_than: 0 }
end 