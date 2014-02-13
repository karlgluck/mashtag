####################################################################################################
#
#  Allows runtime checks to be performed to make sure that assumptions made during code hold true
#  at execution.  "confirm" provides conditional execution that can allow problems to be cleaned up
#  to prevent errors from crashing software or creating undefined behavior.
#
#  Authors:
#       Karl Gluck
#
#---------------------------------------------------------------------------------------------------


#---------------------------------------------------------------------------------------------------
# 
# Tests an expression, and reports an error if it fails.  Allows conditional
# execution of code to handle issues.  If no conditional execution is provided,
# the problem is similar to 'assert'; however, in release mode an empty confirm
# will evaluate its arguments then discard the result, whereas an assert will
# become a no-op.
#
# confirm <expression> ?then <when true>? ?else <when false>?
#
# e.g. confirm {$a} then { ... }
#      confirm {$b} else { ... }
#      confirm {$c}
#      confirm {$d} then { ... } else { ... }
#
# Authors:
#   Karl Gluck
#
#---------------------------------------------------------------------------------------------------
@debug proc confirm {expression args}  {
    lassign $args _condition_ _pred_ _else_ _false_
    catch {set result [uplevel 1 "expr {$expression}"]} exception
    if {[info exists result] && $result} {
        if {$_condition_ == "then"} {
            set code [catch {uplevel 1 $_pred_} res]
            if {$code} { return -code $code $res }
            return {}
        }
    } else {
        if {[info exists result]} {
            error "confirm {$expression} failed:"
        } else {
            error "confirm {$expression} threw exception: $exception"
        }
    }
}

@debug @describe "confirm (@debug mode)" {
    beforeEach {
        catch { unset set_by_confirm }
    }
    it "throws an error on failure" {
        expect {confirm {0} then {}} to throw an error
    }
    it "executes 'then' on success" {
        confirm {1} then {set set_by_confirm 1}
        expect {set_by_confirm} to be defined
    }
    it "never executes 'else'" {
        catch { confirm {0} else { set set_by_confirm 1 } }
        expect {set_by_confirm} to be undefined
    }
    it "evaluates arguments even without then/else clauses" {
        catch { confirm {[set set_by_confirm 1]} }
        expect {set_by_confirm} to be defined
    }
}


#---------------------------------------------------------------------------------------------------
# The release mode of confirm has the same behavior, except that nothing is
# evaluated if there is only an expression with no then/else clause
#---------------------------------------------------------------------------------------------------
@release proc confirm {args} {
    lassign $args expression _condition_ _pred_ _else_ _false_
    set code [catch {
        if {$_condition_ == "else"} {
            uplevel 1 "if {! ([expr {$expression}])} then {$_pred_}"
        } elseif {$_condition_ == "then"} {
            uplevel 1 "if {$expression} then {$_pred_} else {$_false_}"
        } else {
            uplevel 1 "expr {$expression}"
        }
    } res]
    return -code $code $res
}

# Self-test for release mode
@release @describe "confirm (@release mode)" {
    beforeEach {
        catch { unset set_by_confirm }
    }
    it "executes 'then' on success" {
        catch { confirm {1} then {set set_by_confirm 1} }
        expect {set_by_confirm} to be defined
    }
    it "does not execute 'then' on failure" {
        catch { confirm {0} then {set set_by_confirm 1} }
        expect {set_by_confirm} to be undefined
    }
    it "executes 'else' on failure" {
        catch { confirm {0} else {set set_by_confirm 1} }
        expect {set_by_confirm} to be defined
    }
    it "does not execute 'else' on success" {
        catch { confirm {1} else {set set_by_confirm 1} }
        expect {set_by_confirm} to be undefined
    }
    it "executes 'then' from then/else on success" {
        catch { confirm {1} then {set set_by_confirm 1} else {} }
        expect {set_by_confirm} to be defined
    }
    it "does not execute 'then' from then/else on failure" {
        catch { confirm {0} then {set set_by_confirm 1} else {} }
        expect {set_by_confirm} to be undefined
    }
    it "executes 'else' from then/else on failure" {
        catch { confirm {0} then {} else {set set_by_confirm 1} }
        expect {set_by_confirm} to be defined
    }
    it "does not execute 'else' from then/else on success" {
        catch { confirm {1} then {} else {set set_by_confirm 1} }
        expect {set_by_confirm} to be undefined
    }
    it "evaluates arguments even without then/else clauses" {
        catch { confirm {[set set_by_confirm 1]} }
        expect {set_by_confirm} to be defined
    }
}

