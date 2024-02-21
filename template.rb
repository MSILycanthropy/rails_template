install_solid_queue = yes?('Do you want to use solid_queue for background processing? (yes/no)')

gem 'solid_queue' if install_solid_queue

gem 'pagy'

gem 'audited'

install_flipper = yes?('Do you want to use flipper for feature flags? (yes/no)')

if install_flipper
  gem 'flipper'
  gem 'flipper-active_record'
end

authentication = ask('What authentication library do you want to use? (sorcery/devise)').presence || 'devise'
use_sorcery = authentication[0] == 's'

if use_sorcery
  gem 'sorcery'
else
  gem 'devise'
end

gem 'better_html'

gem 'paranoia'

gem 'view_component'

gem 'platform_agent'

literally_1984 = yes?('Is it 1984? (y/n)')

if literally_1984
  gem 'audits1984'
  gem 'console1984'
end

gem_group :development, :test do
  gem 'awesome_print'

  gem 'brakeman'

  gem 'rubocop'

  gem 'rubocop-shopify'

  gem 'rubocop-rails-omakase'

  gem 'faker'

  gem 'erb_lint'
end

gem_group :development do
  gem 'better_errors'

  gem 'binding_of_caller'

  gem 'i18n-tasks'
end

# Install stuff

after_bundle do
  generate('solid_queue:install') if install_solid_queue
  generate('audited:install')

  if use_sorcery
    initializer 'sorcery_active_record_patch.rb', <<~SORCERY
      # frozen_string_literal: true

      # TODO: Remove this when Sorcery merges https://github.com/Sorcery/sorcery/pull/352
      class ActiveRecord::Base
        class << self
          def timestamped_migrations
            ActiveRecord.timestamped_migrations
          end
        end
      end
    SORCERY

    generate('sorcery:install', 'remember_me', 'reset_password', 'external')
  end

  generate('flipper:setup') if install_flipper
  rails_command('console1984:install:migrations') if literally_1984

  file '.rubocop.yml', <<~RUBOCOP
    inherit_gem:
      rubocop-rails-omakase: rubocop.yml
      rubocop-shopify: rubocop.yml

    AllCops:
      NewCops: enable
  RUBOCOP

  file '.better-html.yml', <<~BETTER_HTML
    allow_single_quoted_attributes: false
  BETTER_HTML

  initializer 'better_html.rb', <<~BETTER_HTML
    BetterHtml.config = BetterHtml::Config.new(YAML.load(File.read('.better-html.yml')))
  BETTER_HTML

  file '.erb-lint.yml', <<~ERB_LINT
    ---
    EnableDefaultLinters: true
    linters:
      ErbSafety:
        enabled: true
        better_html_config: .better-html.yml
      Rubocop:
        enabled: true
        rubocop_config:
          inherit_from:
            - .rubocop.yml
  ERB_LINT

  file '.envrc', <<~ENVRC
    RUBY_DEBUG_IRB_CONSOLE=1
  ENVRC

  inside('app/models') do
    file 'current.rb', <<~CURRENT
      class Current < ActiveSupport::CurrentAttributes
        attribute :user, :platform
      end
    CURRENT

    file 'application_platform.rb', <<~PLATFORM
      class ApplicationPlatform < PlatformAgent
      end
    PLATFORM
  end

  unless use_sorcery
    devise_model = ask('What do you want to call the devise model? (User)').presence || 'User'

    generate('devise:install') unless use_sorcery
    generate('devise', devise_model) unless use_sorcery
  end

  if yes?('Do you want the github workflow? (POSTGRES ONLY)')
    file '.github/workflows/rubyonrails.yml', <<~GITHUB
      # This workflow uses actions that are not certified by GitHub.  They are
      # provided by a third-party and are governed by separate terms of service,
      # privacy policy, and support documentation.
      #
      # This workflow will install a prebuilt Ruby version, install dependencies, and
      # run tests and linters.
      name: "Ruby on Rails CI"
      on:
        push:
          branches: [ "main" ]
        pull_request:
          branches: [ "main" ]
      jobs:
        test:
          runs-on: ubuntu-latest
          services:
            postgres:
              image: postgres:11-alpine
              ports:
                - "5432:5432"
              env:
                POSTGRES_DB: rails_test
                POSTGRES_USER: rails
                POSTGRES_PASSWORD: password
          env:
            RAILS_ENV: test
            DATABASE_URL: "postgres://rails:password@localhost:5432/rails_test"
          steps:
            - name: Checkout code
              uses: actions/checkout@v3
            # Add or replace dependency steps here
            - name: Install Ruby and gems
              uses: ruby/setup-ruby@v1.171.0
              with:
                bundler-cache: true
            # Add or replace database setup steps here
            - name: Set up database schema
              run: bin/rails db:schema:load
            # Add or replace test runners here
            - name: Run tests
              run: bin/rake

        lint:
          runs-on: ubuntu-latest
          steps:
            - name: Checkout code
              uses: actions/checkout@v3
            - name: Install Ruby and gems
              uses: ruby/setup-ruby@v1.171.0
              with:
                bundler-cache: true
            # Add or replace any other lints here
            - name: Security audit dependencies
              run: bundle exec bundle-audit --update
            - name: Security audit application code
              run: bundle exec brakeman -q -w2
            - name: Lint Ruby files
              run: bundle exec rubocop --parallel
    GITHUB
  end

  rails_command('db:prepare') if yes?('Do you want the DB created? (y/n)')

  puts 'Things to do after: '
  puts ' - Setup Current with platform and user in ApplicationController'
  puts ' - Setup authentication in ApplicationController'
  puts ' - Setup console1984 and audits194'
  puts ' - Do devise stuff' unless use_sorcery
  puts ' - Have fun coding ;)'
end
