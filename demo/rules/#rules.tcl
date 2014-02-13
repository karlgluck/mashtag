rule "c = a + b" in {a b} out {c} always { set c [expr {$a + $b}] }

rule "write d" out {d} always { set d "D" }
