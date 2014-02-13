####################################################################################################
# 
# Assert works like a confirm, except that it just checks the validity of all of the argument
# expressions, doesn't provide conditional execution, and is a no-op in release mode.  One key
# difference is that it does not evaluate the arguments in release mode.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
@debug proc assert {args} { 
    foreach arg $args {
        if {![uplevel 1 [format {expr {%s}} $arg]]} {
            throw "assertion failed:  $arg"
        }
    }
}
@release proc assert {args} { }

@debug @describe "assert (@debug mode)" {
    it "throws an error on failure" {
        expect {assert {0}} to throw an error
        expect {assert {1} {1} {0}} to throw an error
    }
    it "does nothing on success" {
        set catch_code [catch {assert {1} ; set set_after_assert 1 }]
        expect {$catch_code} to be equal to 0
        expect {set_after_assert} to be defined
    }
    it "evaluates all arguments" {
        set catch_code [catch { assert {1} {[set set_inside_assert 1]} }]
        expect {$catch_code} to be equal to 0
        expect {set_inside_assert} to be defined
    }
}

@release @describe "assert (@release mode)" {
    afterEach { catch { unset set_after_assert } }
    it "does not do anything on failure" {
        catch {assert {0} ; set set_after_assert 1 }
        expect {set_after_assert} to be defined
    }
    it "does not do anything on success" {
        set catch_code [catch {assert {1} ; set set_after_assert 1 }]
        expect {$catch_code} to be equal to 0
        expect {set_after_assert} to be defined
    }
    it "does not evaluate arguments" {
        set catch_code [catch {assert {[set set_inside_assert 0]} }]
        expect {$catch_code} to be equal to 0
        expect {set_inside_assert} to be undefined
    }
}
