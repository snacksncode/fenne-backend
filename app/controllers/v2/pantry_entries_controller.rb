module V2
  class PantryEntriesController < ApplicationController
    class CreatePantryEntryContract < Dry::Validation::Contract
      params do
        required(:product_id).filled(:integer)
        optional(:quantity_remaining).maybe(:float)
        optional(:last_acquired).maybe(:string)
      end
    end

    class UpdatePantryEntryContract < Dry::Validation::Contract
      params do
        optional(:quantity_remaining).maybe(:float)
        optional(:last_acquired).maybe(:string)
      end
    end

    def index
      render_success(PantryEntrySerializer.render_many(entries.detail.order(:created_at)))
    end

    def create
      attrs = pantry_entry_create_params
      product = @current_user.family.products.find(attrs[:product_id])

      add = PantryEntryWriter.new(
        family: @current_user.family,
        product: product
      )

      if add.add(
        quantity_remaining: attrs[:quantity_remaining],
        last_acquired: attrs[:last_acquired]
      )
        invalidate_pantry!
        render_success(PantryEntrySerializer.render(add.entry), status: add.created? ? :created : :ok)
      else
        render_error(add.errors)
      end
    end

    def update
      update = PantryEntryWriter.new(family: @current_user.family, entry: pantry_entry)
      attrs = pantry_entry_update_params

      if update.set(
        quantity_remaining: attrs[:quantity_remaining],
        last_acquired: attrs[:last_acquired]
      )
        invalidate_pantry!
        return render_success if update.entry.destroyed?

        render_success(PantryEntrySerializer.render(update.entry))
      else
        render_error(update.errors)
      end
    end

    def destroy
      pantry_entry.destroy
      invalidate_pantry!
      render_success
    end

    private

    def entries
      @current_user.family.pantry_entries
    end

    def pantry_entry
      entries.find(params[:id])
    end

    def pantry_entry_create_params
      validate_params!(CreatePantryEntryContract)
    end

    def pantry_entry_update_params
      validate_params!(UpdatePantryEntryContract)
    end
  end
end
