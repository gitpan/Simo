package Data::Magazine;
use Simo( base => 'Data::Book' );

sub price : Attr { ac default => 3 }

1;
