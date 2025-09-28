# frozen_string_literal: true

class FlowersController < ApplicationController
  def index
    @cache_status = false
    @flowers = Rails.cache.fetch('flowers_list', expires_in: 1.minute) do
      @cache_status = true
      Flower.all.to_a
    end
  end

  def show
    @flower = Flower.find(params[:id])
  end

  def create
    @flower = Flower.new(flower_params)

    if @flower.save
      handle_flower_creation
    else
      redirect_to root_path, alert: 'Failed to create flower'
    end
  end

  private

  def flower_params
    {
      color: random_color,
      number_of_petals: rand(10..50)
    }
  end

  def random_color
    %w[Red Blue Yellow Pink Purple Orange White Violet].sample
  end

  def handle_flower_creation
    if Flower.count >= 12
      remove_random_flowers
    else
      create_success_response
    end
  end

  def remove_random_flowers
    number_to_remove = rand(6..10)
    flowers_to_remove = Flower.order('RAND()').limit(number_to_remove)
    removed_count = flowers_to_remove.destroy_all.length
    Rails.cache.delete('flowers_list')
    flash[:notice] = "Garden got too crowded! #{removed_count} flowers were removed to make space 🌸"
    redirect_to root_path
  end

  def create_success_response
    Rails.cache.delete('flowers_list')
    flash[:notice] = 'New flower sprouted! 🌸'
    redirect_to root_path
  end
end 