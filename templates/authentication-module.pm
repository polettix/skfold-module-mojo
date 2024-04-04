package [% module %];
use v5.24;
use warnings;
use experimental 'signatures';

use Exporter 'import';

######### FIXME ###########################################################
#
# This is just a little more than a stub!
#

sub load_user ($app, $uid) {
   state $user_for = {
      foo => {
         name => 'Foo De Galook',
         password => 'FOO',
      },
      bar => {
         name => 'Bar Bazius',
         password => 'BAR',
      },
      admin => {
         name => 'Ad Ministrator',
         password => 'admin',
      },
   };
   return unless exists($user_for->{$uid});
   return $user_for->{$uid};
}

sub validate_user ($controller, $username, $password, $extra) {
   my $user = load_user($controller->app, $username) or return;
   return $username if $user->{password} eq $password;
}

1;
