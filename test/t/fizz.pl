#!perl -l
print $_%15?$_%5?$_%3?$_:Fizz:Buzz:FizzBuzz for(1..100)

