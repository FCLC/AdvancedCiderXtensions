//
//  main.swift
//  AdvancedCiderXtensions
//
//  Created by FelixCLC on 2023-12-19.
//
//  License=MIT
//
//  reach me at @fclc@mast.hpc.social

import Foundation
import Accelerate

/*
 This is a silly little app to check out the DGEMM, SGEMM, and eventually
 BGEMM, HGEMM  QGEMM performance of various SoCs supported by apple and their
 performance under accelerate.
 
 hardware features means that sometimes accelerate will use AVX {1,2,512f}
 Other times it will use NEON/ASIMD, sometimes {TOP SECRET THING THAT ISN'T
 A SECRET AT ALL}, and sometime in the future, hopefully SVE, streaming SVE
 and the big one, SME
 
 */

/*
 We care about 3 spans of intervals for performance metrics.
 Specifically:
 
 1. Powers of 10; 10^N because silly little humans, especially in the west
 are taught to think in terms of, and use, Base10
 
 2. Powers of 2; 2^N because silly little computers, especially the modern
 ones, are almost always Base 2 systems, driving design decisions in caches,
 base WORD sizes, FPU length etc.
 
 3. Powers of some prime between 2 and 10, so that we get a sense of things
 that don't line up particularly well for optimizations commonly made between
 Algs designed for points 1 and 2.
 Because it's late when I'm writing this, I'll choose 3, because of the options
 3, 5, 7, five is already part of Base10 covered in 2, and 7 is just boring.
 
 
 */

//Greet the user because we're nice peopleTM
print("Lets brew some cider, hopefully not vinegar!")


//Have the user tell us how much ram they have; I don't want to deal with
// sysctl() for my first swift app
print("Welcome! How many GBs of memory are in your Orchard?", terminator: "")
print("")

var memsize: Int64 = 0
// needs to be a 64 bit int when we convert to bytes


if let input = readLine() {
    if let number = Int64(input) {
        let bytes_available = number * 1000000000
        // Gigabytes to Bytes
        
        print("You entered \(number) GB")
        memsize = bytes_available
    }
    else{
        print("Why you trying to break the app?!? (╯°□°）╯︵ ┻━┻")
        exit(0) //on garbage input, scold the user with something playfull
        
    }
}

let powers: [Int32] = determine_Size(memory_capacity:memsize)
//array of 3 entries. Those entries are the powers to which we can raise
//while staying within the machines memory footprint




var test_point: Int = 0

//loop counter declaration

var test_scope:Int = Int(powers.reduce(0, +))
//total number of tests.

/*
 NOTE: it feels like swift would have an integer array sum function built in.
 
 something like the above would instead look like:
 test_scope = powers.sum()
 
 the closest equivalent is a rather nice pattern of array.reduce(0.+)
 it comes courtesy of @fay59@tech.lgbt, @fracai@mastodon.social,
 and @samwich@mastodon.social on mastodon/the fediverse
 
 */

var tests: [Int] = Array(repeating: 0, count: test_scope)
//array sized to hold the various tests sizes we're going to run

var results: [Double] = Array(repeating: 0, count: test_scope)


while(test_point<powers[0]){
    
    //Base 2 tests are incerted into tests[]
    tests[test_point] = 2<<test_point
    
    test_point+=1
    
}

tests.sort()
//All the values in tests[] are > 0, effectively shifts base2 tests to the back

//Base3 tests are incerted into tests[]


tests[0] = 3 //first value

test_point = 1 // start at the second value, since we refer to the second value
//it's ugly compared to a recursive solution, but it's also stupid easy to read
// for my silly C pilled brain
while(test_point<powers[1]){
    
    tests[test_point] = 3*tests[test_point-1]
    
    test_point+=1
}

tests.sort()
//All the values in tests[] are > 0, effectively shifts b2&b3 tests to the back

//Base 10 tests are incerted into tests[]

tests[0] = 10

test_point = 1 // start at the second value, since we refer to the second value
//it's ugly compared to a recursive solution, but it's also stupid easy to read
// for my silly C pilled brain



while(test_point<powers[2]){
    
    tests[test_point] = 10*tests[test_point-1]
    
    test_point+=1
}

// lets actually sort them now
tests.sort()

print("Running the following tests:",tests)


test_point = 0 //reset counter
//allocate the arrays to be of maximum size:

let matrix_size: Int = tests[test_scope-1]*tests[test_scope-1]
let matrix_dimensions: Int32 = Int32(tests[test_point])

var mat_A: [Double] = Array<Double>(repeating: 0.0, count: matrix_size)
var mat_B: [Double] = Array<Double>(repeating: 0.0, count: matrix_size)
var mat_C: [Double] = Array<Double>(repeating: 0.0, count: matrix_size)


// fill the array with random data
print("Filling the matrices with random data, this may take a while...")

var i = 0

while(i<matrix_size)
{
    mat_C[i] = Double.random(in: 2.71828...3.14159)
    mat_B[i] = mat_C[i] + 1
    mat_A[i] = 2*mat_B[i]
    i += 1
    // if you want you can comment out the mat_B and mat_A lines above
    //and instead uncomment the two below for full "random" data
    
    //                  THIS IS REALLY SLOW!!!!
    
    //mat_B[i] = Double.random(in: 2.71828...3.14159)
    //mat_A[i] = Double.random(in: 2.71828...3.14159)
    
}

// let the system cool down for a moment
print("taking 10 seconds to avoid SOC hot spotting, normalizing clocks etc.")
print("")
sleep(10)




repeat{
    
    let matrix_dimensions: Int32 = Int32(tests[test_point])
    
    //timer start
    let start = DispatchTime.now()
    
    
    //call accelerate
    cblas_dgemm(CblasColMajor, CblasNoTrans, CblasTrans, matrix_dimensions,
                matrix_dimensions, matrix_dimensions, 1.0, &mat_A,
                matrix_dimensions, &mat_B, matrix_dimensions, 1.0,
                &mat_C, matrix_dimensions)
    
    // DGEMM AKA IEEE 754 Binary64 generalized
    // matrix multiply.
    
    //timer end
    let end = DispatchTime.now()
    
    
    //delta between end and start
    let delta = Double((end.uptimeNanoseconds - start.uptimeNanoseconds))
    
    // for calculating GFLOPS
    let edge = Double(matrix_dimensions)
    
    // Calculate GFLOPS
    let Gflops = 2.0*Double(edge*edge*edge) / ( Double(delta))
    
    // we multiply by 2 since technically N^3 is the FMA complexity, but
    // convension dictates that an FMA is 2 operations, a multiply and an add
    
    // convenient thing: if you're outputing in Gflops you don't have to change
    // the units of a nanosecond timer: both are 10^9 and cancel out
    
    results[test_point]=Gflops
    
    print("For {n=m=k}=",matrix_dimensions, " performance is ", Gflops, "GFLOPS")
    
    //end timer, then convert time and size of matrix to Gflops
    
    
    //take a break before doing the next matrix size
    sleep(1)
    
    
    test_point += 1
}while(test_point < test_scope) //do while loop in swift is repeat{}while()


// human facing dialog

print("Lower than you thought? Maybe consider a different kind of Apple?")
print("Up to the task? Enjoy a nice refreshing brew; you've earned it!")
print("")
print("Please share the following 2 lines & your device model with the author")
print("(typically under the name @FCLC or @FelixCLC on most platforms)")
print("")
print(tests)
print(results)



// how to do functions in Swift
func determine_Size(memory_capacity: Int64)-> [Int32] {
    
    //use user input of memory capacity to calculate max bounds for matrices
    
    var matrix_dimensions: Int64 = Int64(memory_capacity)
    
    matrix_dimensions = matrix_dimensions/8
    // 64 bits / 8 bytes give Bytes to entries
    matrix_dimensions = matrix_dimensions/4
    // 3 arrays, so / 3 would be the typical idea here, but because of
    // matrix transposition memory requirements, leaving space for the DE
    // and the kernel (on top of other apps), it's better to leave additional
    //margin
    matrix_dimensions = Int64(Double (matrix_dimensions).squareRoot())
    // we want N from NxN, so invert to root(N)
    
    // array of 3 entries, one for each of the max powers to raise for {2,3,10}
    
    var powers: [Int32] = Array(repeating: 0, count: 3)
    // Power of 2:
    powers[0] = Int32(log2(Double (matrix_dimensions)))
    
    // Note: Swift doesn't have a clean power of X function AFAIK
    // since LogB(x) = LogD(x)/LogD(B) we can do: log(val)/log(NEW BASE)
    
    //Throwback to Madame I. Turcot, forever my goated math prof *o7*
    
    // Power of 3:
    powers[1] = Int32(log2(Double (matrix_dimensions))/log2(3.0))
    // Power of 10
    powers[2] = Int32(log2(Double (matrix_dimensions))/log2(10.0))
    
    
    return powers
}



