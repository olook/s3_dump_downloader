BEGIN { FS = "\t"; OFS = "\t" }
{if ($2 == 10) print $1, $3}
