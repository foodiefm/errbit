require 'phantomjs/poltergeist'
require 'capybara/rspec'
require 'capybara/poltergeist'

Capybara.javascript_driver = :poltergeist

OmniAuth.config.test_mode = true

def mock_auth(user = "test_user", token = "abcdef", email = 'errbit@errbit.example.com')
  OmniAuth.config.mock_auth[:github] = Hashie::Mash.new(
    'provider'    => 'github',
    'uid'         => '1763',
    'extra'       => {
      'raw_info' => {
        'login' => user
      }
    },
    'credentials' => {
      'token' => token
    }
  )

  OmniAuth.config.mock_auth[:google_oauth2] = Hashie::Mash.new(
    provider: 'google',
    uid: user,
    info: {
      email: email,
      name: user
    }
  )
end

def log_in(user)
  visit '/'
  fill_in :user_email, with: user.email
  fill_in :user_password, with: 'password'
  click_on I18n.t('devise.sessions.new.sign_in')
end
