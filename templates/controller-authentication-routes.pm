package [% module %];
use Mojo::Base '[% all_modules.controller_module %]', -signatures;

sub set_account ($self) {
   my $acct = $self->is_user_authenticated ? $self->current_user : undef;
   $self->stash(account => $acct);
   return 1;
}

# API-level authentication useable example routes

# this can be used in a "under()" scenario to move on towards private
# routes or stop here.
sub api_check ($self) {
   return 1 if $self->is_user_authenticated;
   return $self->render(json => {status => 'error'}, status => 401);
}

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
sub check ($self) {
   return 1 if $self->is_user_authenticated;
   $self->redirect_to('/');
   return 0; # false - stop going down
}

sub do_logout ($self) {
   $self->logout;
   return $self->redirect_to('/');
}

sub show_login ($self) {
   if ($self->is_user_authenticated) { # no point in showing login
      $self->redirect_to('/auth');
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
      $self->redirect_to('/auth')
   }
   else {
      $self->flash(message => 'Error', status => 'error');
      $self->redirect_to('/')
   }
   return;
}

1;
