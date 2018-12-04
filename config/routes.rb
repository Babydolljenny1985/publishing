Rails.application.routes.draw do
  get 'errors/not_found'

  get 'errors/internal_server_error'

  # Putting pages first only because it"s the most common:
  # TODO: move all the silly extra things to their own resources (I think).
  resources :pages, only: [:index, :show] do
    get 'autocomplete', on: :collection
    get 'topics', on: :collection
    get 'breadcrumbs'
    get 'comments'
    get 'create_topic'
    get 'classifications'
    # NOTE this is a Rails collecton (as opposed to member), *not* an EOL
    # collection:
    get 'clear_index_stats', on: :collection
    get 'details'
    get 'literature_and_references'
    get 'maps'
    get 'media'
    get 'articles'
    get 'names'
    get 'reindex'
    get 'data'

    get 'overview', :to => redirect("/pages/%{page_id}", :status => 301)
  end

  resources :data, only: [:show]

  # Putting users second only because they tend to drive a lot of site behavior:
  devise_for :users, controllers: { registrations: "user/registrations",
                                    sessions: "user/sessions",
                                    omniauth_callbacks: "user/omniauth_callbacks"}
  resources :users do
    collection do
      get "autocomplete"
      post "delete_user", defaults: { format: "json" }
      get "search"
    end
    resources :user_downloads, only: [:show]
  end

  # All of the "normal" resources:
  resources :articles, only: [:show]
  resources :collections do
    get "logs"
    resources :collected_pages, only: [:index]
    # TODO: this is not very restful; should be a nested resource, but the terms
    # become somewhat tricky, so cheating for now. These aren't really
    # "public-facing URLs" anyway, so less concerned about it.
    post 'add_user'
    post 'remove_user'
  end
  resources :collection_associations, only: [:new, :create, :destroy]
  resources :collected_pages
  resources :media, only: [:show]
  resources :open_authentications, only: [:new, :create]
  resources :page_icons, only: [:create]
  resources :resources, only: [:index, :show] do
    get 'clear_publishing', on: :collection
    get 'sync', on: :collection
    get 'import_traits'
    get 'republish'
    get 'reindex'
    resources :import_logs, only: [:show]
    resources :nodes, only: [:index]
  end
  resources :search_suggestions
  resources :home_page_feeds, :only => [:index, :new, :create] do
    post "publish" => "home_page_feeds#publish", :as => "publish"
    resources :home_page_feed_items, :as => "items", :only => [:index, :new, :edit, :create, :update, :destroy]
  end

  scope '/api' do
    id_match = /[-\w\.,]+(?=\.(json|xml))/
    # id_match = /[-\w\.]+/
    # ping is a bit of an exception - it didn't really get versioned and takes no ID
    scope '/ping' do
      get '/1.0' => 'api_ping#index', id: id_match, format: /json|xml/
      get '/' => 'api_ping#index', id: id_match, format: /json|xml/
    end
    scope '/pages' do
      get '/1.0/:id' => 'api_pages#index', id: id_match, format: /json|xml/
      get '/:version' => 'api_pages#index', version: /1\.0/, id: id_match, format: /json|xml/
      get '/:id' => 'api_pages#index', id: id_match, format: /json|xml/
    end
    scope '/search' do
      get '/1.0/:id' => 'api_search#index', id: id_match, format: /json|xml/
      get '/:q' => 'api_search#index', id: id_match, format: /json|xml/
      get '/:version' => 'api_search#index', version: /1\.0/, id: id_match, format: /json|xml/
    end
    scope '/collections' do
      get '/1.0/:id' => 'api_collections#index', id: id_match, format: /json|xml/
      get '/:id' => 'api_collections#index', id: id_match, format: /json|xml/
      get '/:version' => 'api_collections#index', version: /1\.0/, id: id_match, format: /json|xml/
    end
    scope '/data_objects' do
      get '/1.0/:id' => 'api_data_objects#index', id: id_match, format: /json|xml/
      get '/:id' => 'api_data_objects#index', id: id_match, format: /json|xml/
      get '/:version' => 'api_data_objects#index', version: /1\.0/, id: id_match, format: /json|xml/
    end
    scope '/data_objects_articles' do
      get '/1.0/:id' => 'api_data_objects#index_articles', id: id_match, format: /json|xml/
      get '/:id' => 'api_data_objects#index_articles', id: id_match, format: /json|xml/
      get '/:version' => 'api_data_objects#index_articles', version: /1\.0/, id: id_match, format: /json|xml/
    end
    scope '/hierarchy_entries' do
      get '/1.0/:id' => 'api_hierarchy_entries#index'
      get '/:id' => 'api_hierarchy_entries#index'
      get '/:version' => 'api_hierarchy_entries#index', version: /1\.0/
    end
    # TODO: we decided we could go live without these. Which is good, they are lame:
    # scope '/hierarchies' do
    #   get '/1.0/:id' => 'api_hierarchies#index'
    #   get '/:id' => 'api_hierarchies#index'
    #   get '/:version' => 'api_hierarchies#index', version: /1\.0/
    # end
    # scope '/provider_hierarchies' do
    #   get '/1.0/:id' => 'api_provider_hierarchies#index'
    #   get '/:id' => 'api_provider_hierarchies#index'
    #   get '/:version' => 'api_provider_hierarchies#index', version: /1\.0/
    # end
    # scope '/search_by_provider' do
    #   get '/1.0/:id' => 'api_search_by_provider#index'
    #   get '/:id' => 'api_search_by_provider#index'
    #   get '/:version' => 'api_search_by_provider#index', version: /1\.0/
    # end
  end


  # This isn't really a model, so we'll go oldschool:
  get "/terms/predicate_glossary" => "terms#predicate_glossary", :as => "predicate_glossary"
  get "/terms/object_term_glossary" => "terms#object_term_glossary", :as => "object_term_glossary"
  get "/terms/object_terms_for_predicate" => "terms#object_terms_for_pred"
  get "/terms/units_glossary" => "terms#units_glossary", :as => "units_glossary"
  get "/terms/new" => "terms#new", :as => "new_term"
  get "/terms/:uri_part" => "terms#show", :as => "term"
  post "/terms/:uri" => "terms#update", :as => "update_term", :constraints => { uri: /http.*/ }
  get "/terms/edit/:uri" => "terms#edit", :as => "edit_term", :constraints => { uri: /http.*/ }
  get "/terms" => "terms#index", :as => "terms"
  get "/terms/fetch_relationships" => "terms#fetch_relationships", :as => "fetch_term_relationships"
  get "/terms/fetch_synonyms" => "terms#fetch_synonyms", :as => "fetch_synonyms"
  get "/terms/fetch_units" => "terms#fetch_units", :as => "fetch_units"

  get "/services/authenticate" => "services#authenticate_service"
  get "/service/cypher" => "service/cypher#query", as: "cypher_query"
  get "/service/cypher_form" => "service/cypher#form", as: "cypher_form"

  post "/collected_pages_media" => "collected_pages_media#destroy", :as => "destroy_collected_pages_medium"
  get "/schema/terms/:uri_part" => "terms#schema_redirect"

  get "/records/:uri" => "traits#show", :as => "term_records", :constraints => { :uri => /http.*/ }
  get "/records/search" => "traits#search", :as => "term_search"
  get "/records/search_results" => "traits#search_results", :as => "term_search_results"
  get "/records/search_form" => "traits#search_form", :as => "term_search_form"

  # Non-resource routes last:
  get "/search" => "search#index",  :as => "search_form"
  get "/search_results" => "search#search", :as => "search"
  #get "/search_suggestions" => "search#suggestions", :as => "search_suggestions"
  get "/search_page" => "search#search_page", :as => "search_page"
  get "/vernaculars/prefer/:id" => "vernaculars#prefer", :as => "prefer_vernacular"
  match '/404', to: 'errors#not_found', via: :all, as: 'route_not_found'
  match '/500', :to => 'errors#internal_server_error', :via => :all

  match '/ping', to: 'pages#ping', via: :all

  # UGLY REDIRECTS FROM V2 THAT WE NEED TO HONOR. TODO: we should clean these up. :|

  scope 'info' do
    get '275', to: redirect('http://discuss.eol.org/c/help')
    get 'help', to: redirect('http://discuss.eol.org/c/help')
    get '9', to: redirect('http://discuss.eol.org/c/help')
    get 'faq', to: redirect('http://discuss.eol.org/c/help')
    get 'press_releases', to: redirect('http://discuss.eol.org/c/news')
    get 'newsletters', to: redirect('http://discuss.eol.org/c/news')
    get 'news', to: redirect('http://discuss.eol.org/c/news')
    get 'secretariat', to: redirect('http://discuss.eol.org/t/contact-us-at-eol/181')
    get '7', to: redirect('http://discuss.eol.org/t/contact-us-at-eol/181')
    get 'Employment', to: redirect('http://discuss.eol.org/t/contact-us-at-eol/181')
    get 'press_kit/', to: redirect('http://discuss.eol.org/t/contact-us-at-eol/181')
    get 'partners', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get 'structured_data_archives', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get '148', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get 'cp_archives', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get '522', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get '329', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get 'cp_plan_export', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get '156', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get '337', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get '147', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get '53', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get 'create_xml', to: redirect('http://discuss.eol.org/t/data-providers-how-to-get-eol-to-evaluate-your-dataset/51')
    get 'featured_collections', to: redirect('http://eol.org/collections/106098')
    get '80', to: redirect('http://namelink.org/')
    get '185', to: redirect('http://scholar.google.com/citations?user=_vcAFF8AAAAJ&hl=en')
    get '181', to: redirect('http://www.yanayacu.org/harold_profile.htm')
    get 'disc_pages', to: redirect('/docs/discover')
    get '461', to: redirect('/docs/discover/biological-classification')
    get 'taxonomy_phylogenetics', to: redirect('/docs/discover/biological-classification')
    get '462', to: redirect('/docs/discover/contribute-to-research')
    get 'contribute_research', to: redirect('/docs/discover/contribute-to-research')
    get 'evolution', to: redirect('/docs/discover/evolution')
    get '528', to: redirect('/docs/discover/evolution')
    get 'discovering_diversity', to: redirect('/docs/discover/how-are-species-discovered')
    get '463', to: redirect('/docs/discover/how-are-species-discovered')
    get '465', to: redirect('/docs/discover/indicator-species')
    get 'indicator_species', to: redirect('/docs/discover/indicator-species')
    get '460', to: redirect('/docs/discover/invasive-species')
    get 'invasive_species', to: redirect('/docs/discover/invasive-species')
    get '466', to: redirect('/docs/discover/model-organisms')
    get 'model_organism', to: redirect('/docs/discover/model-organisms')
    get '467', to: redirect('/docs/discover/naming-species')
    get 'naming_species', to: redirect('/docs/discover/naming-species')
    get '468', to: redirect('/docs/discover/what-is-a-species')
    get 'species_concepts', to: redirect('/docs/discover/what-is-a-species')
    get 'about_biodiversity', to: redirect('/docs/discover/what-is-biodiversity')
    get '464', to: redirect('/docs/discover/what-is-biodiversity')
    get '323', to: redirect('/docs/what-is-eol/archives/eol-computable-data-challenge')
    get '345', to: redirect('/docs/what-is-eol/archives/eol-computable-data-challenge')
    get '296', to: redirect('/docs/what-is-eol/archives/pensoft-open-access-funding-partnership')
    get 'fellows', to: redirect('/docs/what-is-eol/archives/rubenstein-fellows-program')
    get '52', to: redirect('/docs/what-is-eol/archives/rubenstein-fellows-program')
    get '485', to: redirect('/docs/what-is-eol/archives/rubenstein-fellows-program')
    get 'toc_subjects', to: redirect('/docs/what-is-eol/content-subject-categories')
    get '98', to: redirect('/docs/what-is-eol/content-subject-categories')
    get 'language_support', to: redirect('/docs/what-is-eol/language-support')
    get '516', to: redirect('/docs/what-is-eol/traitbank')
    get 'traitbank', to: redirect('/docs/what-is-eol/traitbank')
    get '520', to: redirect('/docs/what-is-eol/traitbank')
    get 'curation_standards', to: redirect('/docs/what-is-eol/whats-new/status-report-for-eol-members')
    get 'discover_get_involved', to: redirect('/docs/what-is-eol/whats-new/status-report-for-eol-members')
    get 'discover', to: redirect('https://education.eol.org/')
    get 'ed_resources', to: redirect('https://education.eol.org/')
    get '351', to: redirect('https://education.eol.org/')
    get '537', to: redirect('https://education.eol.org/')
    get '577', to: redirect('https://education.eol.org/')
    get '498', to: redirect('https://education.eol.org/')
    get 'disc_model', to: redirect('https://education.eol.org/')
    get 'learning_and_education_working_group', to: redirect('https://education.eol.org/')
    get 'disc_observer', to: redirect('https://education.eol.org/')
    get 'discover_tools_resources', to: redirect('https://education.eol.org/')
    get 'disc_media', to: redirect('https://education.eol.org/')
    get 'disc_collections', to: redirect('https://education.eol.org/')
    get '558', to: redirect('https://education.eol.org/')
    get 'disc_google_earth', to: redirect('https://education.eol.org/earth_tours')
    get 'disc_google_earth?language=ar', to: redirect('https://education.eol.org/earth_tours')
    get 'impacts', to: redirect('https://education.eol.org/lesson_plans')
    get 'podcasts', to: redirect('https://education.eol.org/podcasts')
    get 'podcast_classification', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_ecology', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_citsci', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_evolution', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_invertebrates', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_mammals', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_behavior', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_impacts', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_amphibians_reptiles', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_plants', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_birds', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_research', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_measure', to: redirect('https://education.eol.org/podcasts')
    get '596', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_fishes', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_microorganisms', to: redirect('https://education.eol.org/podcasts')
    get '585', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_fungi', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_observe', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_insects', to: redirect('https://education.eol.org/podcasts')
    get '573', to: redirect('https://education.eol.org/podcasts')
    get 'podcasts_experiment', to: redirect('https://education.eol.org/podcasts')
    get '200', to: redirect('https://en.wikipedia.org/wiki/Jos%C3%A9_Sarukh%C3%A1n_Kermez')
    get 'discover_articles', to: redirect('/docs/discover')
    get '356', to: redirect('/docs/discover')
    get '526', to: redirect('/docs/discover/algae')
    get 'algae', to: redirect('/docs/discover/algae')
    get '526?language=ar', to: redirect('/docs/discover/algae/%D8%A7%D9%84%D8%B7%D8%AD%D8%A7%D9%84%D8%A8')
    get 'amphibians', to: redirect('/docs/discover/amphibians')
    get '440', to: redirect('/docs/discover/amphibians')
    get '440?language=ar', to: redirect('/docs/discover/amphibians/%D8%A7%D9%84%D8%A8%D8%B1%D9%85%D8%A7%D8%A6%D9%8A%D8%A7%D8%AA')
    get '440?language=pt-BR', to: redirect('/docs/discover/amphibians/anfibios')
    get '440?language=fr', to: redirect('/docs/discover/amphibians/les-amphibiens')
    get '428', to: redirect('/docs/discover/animals')
    get 'animals', to: redirect('/docs/discover/animals')
    get '428?language=ar', to: redirect('/docs/discover/animals/%D9%85%D8%A7-%D9%87%D9%8A-%D8%A7%D9%84%D8%AD%D9%8A%D9%88%D8%A7%D9%86%D8%A7%D8%AA%D8%9F')
    get '428?language=pt-BR', to: redirect('/docs/discover/animals/animais')
    get '457', to: redirect('/docs/discover/archaea')
    get 'archaea', to: redirect('/docs/discover/archaea')
    get 'bacteria', to: redirect('/docs/discover/bacteria')
    get '455', to: redirect('/docs/discover/bacteria')
    get '455?language=ar', to: redirect('/docs/discover/bacteria/%D8%A7%D9%84%D8%A8%D9%83%D8%AA%D9%8A%D8%B1%D9%8A%D8%A7')
    get '439', to: redirect('/docs/discover/birds')
    get 'birds', to: redirect('/docs/discover/birds')
    get '444', to: redirect('/docs/discover/crustaceans')
    get 'crustaceans', to: redirect('/docs/discover/crustaceans')
    get '442', to: redirect('/docs/discover/fishes')
    get 'fishes', to: redirect('/docs/discover/fishes')
    get '442?language=ar', to: redirect('/docs/discover/fishes/%D8%A7%D9%84%D8%A3%D8%B3%D9%85%D8%A7%D9%83')
    get '442?language=pt-BR', to: redirect('/docs/discover/fishes/peixes')
    get '450', to: redirect('/docs/discover/flowering-plants')
    get 'flowering_plants', to: redirect('/docs/discover/flowering-plants')
    get '452', to: redirect('/docs/discover/fungi')
    get 'fungi', to: redirect('/docs/discover/fungi')
    get 'insects', to: redirect('/docs/discover/insects')
    get '446', to: redirect('/docs/discover/insects')
    get '443', to: redirect('/docs/discover/invertebrates')
    get 'invertebrates', to: redirect('/docs/discover/invertebrates')
    get '443?language=ar', to: redirect('/docs/discover/invertebrates/%D9%85%D8%A7-%D9%87%D9%8A-%D8%A7%D9%84%D9%84%D8%A7%D9%81%D9%82%D8%A7%D8%B1%D9%8A%D8%A7%D8%AA%D8%9F')
    get '438', to: redirect('/docs/discover/mammals')
    get 'mammals', to: redirect('/docs/discover/mammals')
    get 'molds', to: redirect('/docs/discover/molds')
    get '454', to: redirect('/docs/discover/molds')
    get '445', to: redirect('/docs/discover/mollusks')
    get 'mollusks', to: redirect('/docs/discover/mollusks')
    get '453', to: redirect('/docs/discover/mushrooms')
    get 'mushrooms', to: redirect('/docs/discover/mushrooms')
    get '449', to: redirect('/docs/discover/plants')
    get 'plants', to: redirect('/docs/discover/plants')
    get '456', to: redirect('/docs/discover/protists-or-protozoa')
    get 'protists', to: redirect('/docs/discover/protists-or-protozoa')
    get '441', to: redirect('/docs/discover/reptiles')
    get 'reptiles', to: redirect('/docs/discover/reptiles')
    get '447', to: redirect('/docs/discover/spiders')
    get 'spiders', to: redirect('/docs/discover/spiders')
    get '447?language=fr', to: redirect('/docs/discover/spiders/les-araignees')
    get 'trees', to: redirect('/docs/discover/trees')
    get '451', to: redirect('/docs/discover/trees')
    get '458', to: redirect('/docs/discover/viruses')
    get 'viruses', to: redirect('/docs/discover/viruses')
    get '448', to: redirect('/docs/discover/worms')
    get 'worms', to: redirect('/docs/discover/worms')
    get 'about', to: redirect('/docs/what-is-eol')
    get 'global_partners', to: redirect('/docs/what-is-eol')
    get '215', to: redirect('/docs/what-is-eol')
    get 'about?language=zh-Hans', to: redirect('/docs/what-is-eol')
    get 'about?language=es', to: redirect('/docs/what-is-eol')
    get '228', to: redirect('/docs/what-is-eol')
    get 'working_groups', to: redirect('/docs/what-is-eol')
    get 'priority_taxa_on_eol', to: redirect('/docs/what-is-eol')
    get 'communities', to: redirect('/docs/what-is-eol')
    get 'taxon_page', to: redirect('/docs/what-is-eol')
    get 'meet_the_team', to: redirect('/docs/what-is-eol')
    get 'discover_global', to: redirect('/docs/what-is-eol')
    get '240', to: redirect('/docs/what-is-eol')
    get 'watch_list', to: redirect('/docs/what-is-eol')
    get 'science_advisors', to: redirect('/docs/what-is-eol')
    get 'species_pages_working_group', to: redirect('/docs/what-is-eol')
    get '287', to: redirect('/docs/what-is-eol')
    get 'technology_providers', to: redirect('/docs/what-is-eol')
    get 'tree_challenge', to: redirect('/docs/what-is-eol')
    get 'api_overview', to: redirect('/docs/what-is-eol/data-services')
    get '152', to: redirect('/docs/what-is-eol/data-services')
    get 'services', to: redirect('/')
    get 'the_history_of_eol', to: redirect('/docs/what-is-eol/eol-history')
    get 'how_is_eol_managed', to: redirect('/docs/what-is-eol/eol-history')
    get '277', to: redirect('/docs/what-is-eol/eol-history')
    get 'terms_of_use', to: redirect('/docs/what-is-eol/terms-of-use')
    get 'citing', to: redirect('/docs/what-is-eol/terms-of-use/citing-eol-and-eol-content')
    get '55', to: redirect('/docs/what-is-eol/terms-of-use/citing-eol-and-eol-content')
    get 'community_conditions', to: redirect('/docs/what-is-eol/terms-of-use/community-conditions-and-comment-policy')
    get 'copyright_and_linking', to: redirect('/docs/what-is-eol/terms-of-use/copyright-and-linking-policy')
    get 'linkstoeol', to: redirect('/docs/what-is-eol/terms-of-use/copyright-and-linking-policy')
    get '322', to: redirect('/docs/what-is-eol/terms-of-use/copyright-and-linking-policy')
    get 'eol_licensing_policy', to: redirect('/docs/what-is-eol/terms-of-use/copyright-and-linking-policy')
    get 'privacy', to: redirect('/docs/what-is-eol/terms-of-use/privacy-policy')
    get 'api_terms', to: redirect('/docs/what-is-eol/terms-of-use/terms-of-use-for-eol-application-programming-interfaces')
    get '169', to: redirect('/docs/what-is-eol/terms-of-use/terms-of-use-for-eol-application-programming-interfaces')
    get 'sept_5', to: redirect('/docs/what-is-eol/whats-new')
    get 'curators', to: redirect('/docs/what-is-eol/whats-new')
    get 'profile', to: redirect('/docs/what-is-eol/whats-new')
    get 'curation', to: redirect('/docs/what-is-eol/whats-new')
    get '220', to: redirect('/docs/what-is-eol/whats-new')
    get '54', to: redirect('/docs/what-is-eol/whats-new')
    get '133', to: redirect('/docs/what-is-eol/whats-new')
    get '250', to: redirect('/docs/what-is-eol/whats-new')
    get 'writing_eol_chapters', to: redirect('/docs/what-is-eol/whats-new')
    get 'contribute', to: redirect('/docs/what-is-eol/whats-new')
    get 'collections', to: redirect('/docs/what-is-eol/whats-new')
    get '252', to: redirect('/docs/what-is-eol/whats-new')
    get 'glossary', to: redirect('/terms')
    get '486', to: redirect('/terms')
    get '499', to: redirect('https://github.com/EOL')
    get 'biodiversity_informatics_working_group', to: redirect('https://github.com/EOL')
    get 'technology', to: redirect('https://github.com/EOL')
    get '222', to: redirect('https://opendata.eol.org/organization/dynamic-hierarchy')
    get 'classification_providers', to: redirect('https://opendata.eol.org/organization/dynamic-hierarchy')
    get '173', to: redirect('https://orcid.org/0000-0002-6185-9404')
    get '175', to: redirect('https://scholar.google.com/citations?user=Rq_QZRwAAAAJ&hl=en')
    get '110', to: redirect('https://scholar.google.com/citations?user=wi0rpUwAAAAJ&hl=nl')
    get 'eol_publications', to: redirect('"https://scholar.google.com/scholar?cites=4654446778241087404&as_sdt=20005&sciodt=0,9&hl=en"')
    get '108', to: redirect('https://stri.si.edu/scientist/david-kenfack')
    get 'disc_bhl', to: redirect('https://www.biodiversitylibrary.org/')
    get '496', to: redirect('https://www.flickr.com/photos/treegrow/8608061735/')
    get 'disc_inaturalist', to: redirect('https://www.inaturalist.org')
    get 'making_observations', to: redirect('https://www.inaturalist.org')
    get '334', to: redirect('https://www.inaturalist.org')
    get '331', to: redirect('https://www.inaturalist.org')
    get '339', to: redirect('https://www.inaturalist.org/guides')
    get 'disc_fieldguides', to: redirect('https://www.inaturalist.org/guides')
    get '330', to: redirect('https://www.inaturalist.org/guides')
    get '359', to: redirect('https://www.inaturalist.org/guides')
    get '23', to: redirect('https://www.linkedin.com/in/graham-higley-a849b74/?originalSubdomain=uk')
    get '22', to: redirect('https://www.linkedin.com/in/james-edwards-6472754/')
    get '70', to: redirect('https://www.researchgate.net/scientific-contributions/2047189989_Myra_C_Hughey')
    get 'tutorials', to: redirect('https://www.slideshare.net/eoleducation/presentations')
    get 'eol_tutorials', to: redirect('https://www.slideshare.net/eoleducation/presentations')
    get '599', to: redirect('https://www.slideshare.net/eoleducation/presentations')
    get '28', to: redirect('https://www.ted.com/talks/e_o_wilson_on_saving_life_on_earth')
  end

  get "/traitbank", to: redirect('https://eol.org/docs/what-is-eol/traitbank')

  root 'home_page#index'

  # This line mounts Refinery's routes at the root of your application.
  # This means, any requests to the root URL of your application will go to Refinery::PagesController#home.
  # If you would like to change where this extension is mounted, simply change the
  # configuration option `mounted_path` to something different in config/initializers/refinery/core.rb
  #
  # We ask that you don't use the :as option here, as Refinery relies on it being the default of "refinery"
  #keep this at the end of the routes (Refinery smetimes can override other routes)
  mount Refinery::Core::Engine, at: Refinery::Core.mounted_path

  scope 'content' do
    scope format: true, constraints: { format: /jpg|png|gif|jpeg/ } do
      get '/*anything', to: proc { [404, {}, ['']] }
    end
  end
  get '*unmatched_route', to: 'application#route_not_found'
end
