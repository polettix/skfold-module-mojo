package [% module %];
use Mojo::Base '[% all_modules.controller_module %]', -signatures;

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


# Useable example for user-level routes

# this can be used in a "under()" scenario to move on towards private
# routes or stop here.
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
   }
   else {
      $self->flash(message => 'Error', status => 'error');
   }
   return $self->redirect_to('/')
}

1;
