package [% module %];
use Mojo::Base '[% all_modules.controller_module %]', -signatures;

sub root ($self) {
   return $self->render(template => 'authenticated/home');
}

1;
