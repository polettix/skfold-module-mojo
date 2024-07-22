package [% module %];
use v5.24;
use warnings;
use experimental 'signatures';

use Exporter 'import';

sub load_user ($app, $uid) {
   return $app->model->authentication->load_user($uid);
}

sub validate_user ($controller, $username, $password, $extra) {
   my $authn = $controller->app->model->authentication;
   return $authn->validate_user($username, $password, $extra);
}

1;
