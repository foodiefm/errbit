require 'acceptance/acceptance_helper'

feature 'Sign in with Google' do
  background do
    allow(Errbit::Config).to receive(:google_authentication).and_return(true)
    Fabricate(:user, google_uid: 'nashby')
    visit root_path
  end

  scenario 'log in via Google with recognized user' do
    mock_auth('nashby')

    click_link 'Sign in with Google'
    expect(page).to have_content I18n.t('devise.omniauth_callbacks.success', kind: 'Google')
  end

  scenario 'reject unrecognized user if authenticating via Google' do
    mock_auth('unknown_user')

    click_link 'Sign in with Google'
    expect(page).to have_content 'There are no authorized users with Google login'
  end
end

feature 'Sign in with Google with allowed domains' do
  background do
    allow(Errbit::Config).to receive(:google_authentication).and_return(true)
    allow(Errbit::Config).to receive(:google_allow_domains).and_return(['errbit.example.com'])
    Fabricate(:user, google_uid: 'nashby')
    Fabricate(:user, email: 'domain-existing@errbit.example.com')
    visit root_path
  end

  scenario 'log in via Google with recognized user' do
    mock_auth('nashby')

    click_link 'Sign in with Google'
    expect(page).to have_content I18n.t('devise.omniauth_callbacks.success', kind: 'Google')
  end

  scenario 'reject users from another domain' do
    mock_auth('nashby', 'foo', 'email@otherdomain.com')

    click_link 'Sign in with Google'
    expect(page).to have_content 'not from allowed domains'
  end

  scenario 'create new user from allowed domains automatically' do
    mock_auth('user', '1234', 'user-1234@errbit.example.com')

    click_link 'Sign in with Google'
    expect(User.where(email: 'user-1234@errbit.example.com').first).to_not be_nil
  end

  scenario 'bind uid to existing user with email from google' do
    mock_auth('new', '123', 'domain-existing@errbit.example.com')

    click_link 'Sign in with Google'
    expect(User.where(email: 'domain-existing@errbit.example.com').first.google_uid).to eql('new')
  end

end
