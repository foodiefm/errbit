class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def github
    github_login = env["omniauth.auth"].extra.raw_info.login
    github_token = env["omniauth.auth"].credentials.token
    github_user  = User.where(github_login: github_login).first
    github_site_title = Errbit::Config.github_site_title

    if github_user.nil? && (github_org_id = Errbit::Config.github_org_id)
      # See if they are a member of the organization that we have access for
      # If they are, automatically create an account
      client = Octokit::Client.new(access_token: github_token)
      client.api_endpoint = Errbit::Config.github_api_url
      org_ids = client.organizations.map(&:id)
      if org_ids.include?(github_org_id)
        github_user = User.create(name: env["omniauth.auth"].extra.raw_info.name, email: env["omniauth.auth"].extra.raw_info.email)
      end
    end

    # If user is already signed in, link github details to their account
    if current_user
      # ... unless a user is already registered with same github login
      if github_user && github_user != current_user
        flash[:error] = "User already registered with #{github_site_title} login '#{github_login}'!"
      else
        # Add github details to current user
        update_user_with_github_attributes(current_user, github_login, github_token)
        flash[:success] = "Successfully linked #{github_site_title} account!"
      end
      # User must have clicked 'link account' from their user page, so redirect there.
      redirect_to user_path(current_user)
    elsif github_user
      # Store OAuth token
      update_user_with_github_attributes(github_user, github_login, github_token)
      flash[:success] = I18n.t "devise.omniauth_callbacks.success", kind: github_site_title
      sign_in_and_redirect github_user, event: :authentication
    else
      flash[:error] = "There are no authorized users with #{github_site_title} login '#{github_login}'. Please ask an administrator to register your user account."
      redirect_to new_user_session_path
    end
  end

  def google_oauth2
    google_uid = env['omniauth.auth'].uid
    google_email = env['omniauth.auth'].info.email
    google_user = User.where(google_uid: google_uid).first
    google_site_title = Errbit::Config.google_site_title

    # if GOOGLE_AUTH_DOMAIN is set, check if email is from that domain
    if Errbit::Config.google_allow_domains && !google_allowed_domain?(google_email)
      flash[:error] = "email '#{google_email}' is not from allowed domains."
      redirect_to new_user_session_path and return
    end

    if current_user
      # ... unless a user is already registered with same google login
      if google_user && google_user != current_user
        flash[:error] = "User already registered with #{google_site_title} login '#{google_email}'!"
      else
        # Add github details to current user
        current_user.update(google_uid: google_uid)
        flash[:success] = "Successfully linked #{google_email} account!"
      end
      # User must have clicked 'link account' from their user page, so redirect there.
      redirect_to user_path(current_user)
    elsif google_user
      flash[:success] = I18n.t 'devise.omniauth_callbacks.success', kind: google_site_title
      sign_in_and_redirect google_user, event: :authentication
    else
      if Errbit::Config.google_allow_domains
        # we've checked already that domain is verified, try to create new
        user = bind_or_create_google_domain_user(google_email,
                                             env['omniauth.auth'].info.name,
                                             google_uid)
        flash[:success] = I18n.t 'devise.omniauth_callbacks.success', kind: google_site_title
        sign_in_and_redirect user, event: :authentication
      else
        flash[:error] = "There are no authorized users with #{google_site_title} login '#{google_email}', Please ask an administrator to register you user account."
        redirect_to new_user_session_path
      end
    end
  end


  private

  def update_user_with_github_attributes(user, login, token)
    user.update_attributes(
      github_login:       login,
      github_oauth_token: token
    )
  end

  def google_allowed_domain?(address)
    domains = Errbit::Config.google_allow_domains || []
    m = Mail::Address.new(address)
    domains.each do |domain|
      return true if m.domain.casecmp(domain).zero?
    end
    return false
  end

  def bind_or_create_google_domain_user(email, name, uid)
    existing_email_user = User.where(email: email).first
    if existing_email_user
      existing_email_user.update_attributes(google_uid: uid)
      return existing_email_user
    end
    return User.create(email: email, name: name, google_uid: uid)
  end

end
