package [% module %];
use Mojo::Base qw< [% all_modules.model_authn_local_module %] -signatures >;

has 'wmdb';
has name => 'db';

sub create ($class, $model, %args) {
   my $wmdb = $args{wmdb} // $model->wmdb or return;
   return $class->new(%args, wmdb => $wmdb);
}

sub load_user_by_id ($self, $id) {
   return $self->wmdb->select(account => '*', { id => $id })->hash;
}

*{load_user} = \&load_user_by_id;

sub load_user_by_name ($self, $name) {
   return $self->wmdb->select(account => '*', { name => $name })->hash;
}

sub save_user ($self, $user) {
   $self->wmdb->upsert(account => $user);
   return $self;
}

1;
