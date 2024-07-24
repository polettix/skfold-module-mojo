package [% module %];
use Mojo::Base '[% all_modules.controller_module %]', -signatures;
use Try::Catch;
use Ouch qw< :trytiny_var >;
use Mojo::Util 'dumper';

# API-level authentication useable example routes

# this can be used in a "under()" scenario to move on towards private
# routes or stop here.
sub api_logout ($self) {
   $self->logout;
   return $self->rendered(204);
}

sub api_login ($self) {
   my $username = $self->param('username');
   my $password = $self->param('password');
   return $self->rendered(204)
      if $self->authenticate($username, $password, {});
   return $self->render(json => {status => 'error'}, status => 401);
}


########################################################################
#
# Local username/password based authentication, either via hash or DB

sub do_logout ($self) {
   $self->logout;
   return $self->redirect_to('/');
}

sub show_login ($self) {
   if ($self->is_user_authenticated) { # no point in showing login
      $self->redirect_to('/');
   }
   else {
      $self->render(template => 'login');
   }
   return;
}

sub do_login ($self) {
   my $username = $self->param('username');
   my $password = $self->param('password');
   if ($self->authenticate($username, $password, {})) {
      $self->flash(message => "Welcome, $username", status => 'ok');
      return $self->redirect_to('/')
   }
   $self->flash(message => 'Authentication error', status => 'error');
   return $self->redirect_to('public_root')
}


########################################################################
#
# SAML2 SSO
sub saml2_login ($self) {
   my $saml2 = $self->model->authentication->instance_for('saml2');
   my ($id, $url) = $saml2->idp_login;
   $self->session->{'saml-id'} = $id;
   $self->signed_cookie('saml-id' => $id, { path => '/' });
   return $self->redirect_to($url);
}

sub saml2_sso_post ($self) {
   my $saml2 = $self->model->authentication->instance_for('saml2');

   try {
      (my $saml_id = $self->signed_cookie('saml-id'))
         or ouch 400, 'Not expecting anything SAML-related';
      defined(my $saml_response = $self->param('SAMLResponse'))
         or ouch 400, 'No SAMLResponse';

      my $user = $saml2->parse_assertion($saml_id, $saml_response);
      my $username = $user->{key};

      $self->authenticate($username, '', $user);
      $self->log->info("logged in: <$username>");
      $self->log->debug(dumper($user));

      $self->flash(message => [info => "Welcome, $user->{fullname}"]);
   }
   catch {
      my $message = bleep() || 'Error: invalid credentials';
      $self->flash(message => [error => $message]);
   };

   return $self->redirect_to('/public');
}

*{saml2_logout} = \&do_logout; # FIXME same method for the time being

1;
