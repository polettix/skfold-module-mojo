package [% module %];
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use [% my $module = V 'all_modules.minion_basic_module'; %][% $module %];

sub register ($self, $app, $config) {
   [% $module %]::sub_register($self, $app, $config);
}

1;
