install_solid_queue = yes?("Do you want to use solid_queue for background processing? (yes/no)")

gem "solid_queue" if install_solid_queue

gem "pagy"

gem "audited"

install_flipper = yes?("Do you want to use flipper for feature flags? (yes/no)")

if install_flipper
  gem "flipper"
  gem "flipper-active_record"
end

authentication = ask("What authentication library do you want to use? (sorcery/devise)").presence || "devise"
use_sorcery = authentication[0] == "s"

if use_sorcery
  gem "sorcery"
else
  gem "devise"
end

gem "better_html"

gem_group :development, :test do
  gem "awesome_print"

  gem "brakeman"

  gem "rubocop"

  gem "rubocop-shopify"

  gem "rubocop-rails-omakase"

  gem "faker"

  gem "erb_lint"
end

gem_group :development do
  gem "better_errors"

  gem "binding_of_caller"

  gem "i18n-tasks"
end

# Install stuff

after_bundle do
  generate("solid_queue:install") if install_solid_queue
  generate("audited:install")

  if use_sorcery
    initializer "sorcery_active_record_patch.rb", <<~SORCERY
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

    generate("sorcery:install", "remember_me", "reset_password", "external")
  end

  generate("flipper:setup") if install_flipper

  file ".rubocop.yml", <<~RUBOCOP
    inherit_gem:
      rubocop-rails-omakase: rubocop.yml
      rubocop-shopify: rubocop.yml

    AllCops:
      NewCops: enable
  RUBOCOP


  file ".better-html.yml", <<~BETTER_HTML
    allow_single_quoted_attributes: false
  BETTER_HTML

  initializer "better_html.rb", <<~BETTER_HTML
    BetterHtml.config = BetterHtml::Config.new(YAML.load(File.read('.better-html.yml')))
  BETTER_HTML

  file ".erb-lint.yml", <<~ERB_LINT
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

  file ".envrc", <<~ENVRC
    RUBY_DEBUG_IRB_CONSOLE=1
  ENVRC

  inside("app/models") do
    file "current.rb", <<~CURRENT
      class Current < ActiveSupport::CurrentAttributes
        attribute :user
      end
    CURRENT
  end

  unless use_sorcery
    devise_model = ask("What do you want to call the devise model? (User)").presence || "User"

    generate("devise:install") unless use_sorcery
    generate("devise", devise_model) unless use_sorcery
  end

  rails_command("db:prepare") if yes?("Do you want the DB created? (y/n)")

  puts "MAKE SURE TO DO THE DEVISE STUFF" unless use_sorcery
end
