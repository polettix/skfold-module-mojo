package [% module %];
use Mojo::Base qw< -base -signatures >;
use Ouch qw< :trytiny_var >;
use Scalar::Util qw< blessed refaddr >;
use Module::Runtime qw< use_module >;

use constant MISSING => [];

has model => sub { ... }, weak => 1;

has providers => sub { return [] };
has _providers => \&_build__providers;

sub _build__providers ($self) {
   my $model = $self->model;
   my (%by_name, @by_sequence);
   for my $candidate ($self->providers->@*) {
      next unless defined($candidate);

      my ($name, $provider);
      if (blessed($candidate)) {
         $provider = $candidate;
         $provider->init_model($model) if $provider->can('init_model');
      }
      elsif (ref($candidate) eq 'CODE') {
         $provider = $candidate->($model);
      }
      else {
         $name = $candidate->{name} if exists($candidate->{name});
         if (defined(my $instance = $candidate->{instance} // undef)) {
            $provider = $instance;
         }
         else {
            my ($class, $args) = $candidate->@{qw< class args >};
            $provider = use_module($class)->create($model, $args->@*);
         }
      }

      next unless defined($provider);
      push @by_sequence, $provider;

      $name //= $provider->name if $provider->can('name');
      $by_name{$name} = $provider if defined($name);
   }
   return { by_name => \&by_name, by_sequence => \@by_sequence };
}

sub instance_for ($s, $n) { $s->_providers->{by_name}->{$n} // undef }

sub _iterate ($self, @args) {
   my $method = (caller(1))[3] =~ s{\A .* ::}{}rmxs;
   for my $provider ($self->_providers->{by_sequence}->@*) {
      my $retval = $provider->$method(@args);
      return $retval if defined $retval;
   }
   return;
}

sub load_user         ($self, $x)    { $self->_iterate($x)    }
sub load_user_by_id   ($self, $id)   { $self->_iterate($id)   }
sub load_user_by_name ($self, $name) { $self->_iterate($name) }
sub validate_user     ($self, @args) { $self->_iterate(@args) }

1;
