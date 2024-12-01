<?php
$in = file_get_contents("1/dummy");
$lines = explode("\n",$in);

$first = [];
$second = [];

$c = count($lines)-1;
for($i=0; $i < $c; $i++) {
				[$first[], $second[]] = explode("   ", $lines[$i]);
}

sort($first);
sort($second);


//var_dump([$first, $second]);

$dists = [];
for($i=0; $i < $c; $i++) {
  $dists[$i] = abs($first[$i] - $second[$i]);
}

//var_dump([$dists, array_sum($dists)]);
echo "part 1: " . array_sum($dists) . PHP_EOL;

$k = 0;
$cache = [];
$sum = [];
for($i=0; $i < $c; $i++) {
				$curr = $first[$i];
				if(!array_key_exists($curr, $cache)) {
								$s = 0;
								for (;$k < $c; $k++) {
												if($second[$k] > $curr) break;
												if($second[$k] < $curr) continue;
												$s += 1;
								}
								$cache[$curr] = $curr * $s;
				}
				$sum[$curr] ??= 0;
				$sum[$curr] += $cache[$curr];
}

//var_dump([$k, $cache, $sum]);
echo "part 2: " . array_sum($sum) . PHP_EOL;
