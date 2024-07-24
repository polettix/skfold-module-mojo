package [% module %];
use Mojo::Base qw< [% all_modules.model_authn_saml2_module %] -signatures >;
use Storable qw< dclone >;

has store => sub { return {} };

sub get ($self, $key) {
   defined(my $rec = $self->store->{$key}) or return;
   return dclone($rec->{data}) if $rec->{expire} > time();
   $self->wipe($key);
   return;
}

sub set ($self, $data, $key, $expire) {
   $self->store->{$key} = {
      expire => $expire,
      data   => $data,
   };
   return $self;
}

sub wipe ($self, $key) {
   delete($self->store->{$key});
   return $self;
}

1;
