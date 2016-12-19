require 'rails_helper'

RSpec.describe CollectedPagesController do
  describe "#new" do
    let(:page) { create(:page) }

    let!(:collection_with_page) do
      collection = create(:collection)
      create(:collected_page, page: page, collection: collection)
      collection
    end

    before { get :new, page_id: page.id }

    it { expect(assigns(:collected_page).page_id).to eq(page.id) }
    it { expect(assigns(:page)).to eq(page) }
    it { expect(assigns(:collection)).to be_a(Collection) }
    it { expect(assigns(:bad_collection_ids)).to include(collection_with_page.id) }
  end

  describe "#create" do  
    let(:page) { create(:page) }
    let(:collection) { create(:collection) }

    let(:collected_page_params) do
      attributes_for(:collected_page, page_id: page.id,
        collection_id: collection.id)
    end

    before do
      post :create, collected_page: collected_page_params
    end

    it { expect(assigns(:collected_page).page_id).to eq(page.id) }
    it { expect(assigns(:collected_page).collection_id).to eq(collection.id) }
    it { expect(flash[:notice]).to match(collection.name) }
    it { expect(flash[:notice]).to match(page.name) }
    it { expect(response).to redirect_to(page) }    
    it { expect(response).not_to render_template(:new) }
  end
  
     
   # describe "#search" do
     # let(:page) { create(:page) }
     # let(:collection) { create(:collection) }
     # create(:collected_page, page: page, collection: collection) 
     # let(:expected) { {methods: page.scientific_name}.to_json }
     # before do 
       # get :search, q: {name: page.name}, collection_id: collection.id 
     # end
     # #TODO revisit this after completeting the todo in collected_pages_controller "JSON results for other types!"
      # it { expect(response.body).to include(expected) }
   # end
   
     describe "#search_results" do
     let(:page) { create(:page) }
     let(:collection) { create(:collection) }
     let(:params) {{q: {name: page.name}, collection_id: collection.id }}
     let(:collected_page) { create(:collected_page, page: page, collection: collection) }
     before do 
       get :search_results, params
     end
     it { expect(response).to render_template("collected_pages/_search_results") }
   end
end
