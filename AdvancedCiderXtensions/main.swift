//
//  main.swift
//  AdvancedCiderXtensions
//
//  Created by FelixCLC on 2023-12-19.
//
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
 
 1. Powers of 10; 10^N because silly little humans, espececially in the west
 are tought to think in terms of, and use, Base10
 
 2. Powers of 2; 2^N because silly little computers, especially the modern
 ones, are almost always Base 2 systems, driving design decisions in caches,
 base WORD sizes, FPU length etc.
 
 3. Powers of some prime between 2 and 10, so that we get a sense of things
 that don't line up particularly well for optimizations commonly made between
 Algs designed for points 1 and 2.
 Because it's late when I'm writing this, I'll choose 3, because of the options
 3, 5, 7, five is already part of Base10 covered in 2, and 7 is just boring.


*/

//macOS crashes completly on allocs that big

//Print something welcoming
print("Lets brew some cider, hopefully not vinegar!")


//Greet the user because we're nice peopleTM

//Have the user tell us how much ram they have; I don't want to deal with
// sysctl() for my first swift app
print("Welcome! How many GBs of memory are in your Orchard?", terminator: "")
print("")

var memsize: Int64 = 0

if let input = readLine() {
    if let number = Int64(input) {
        let bytes_available = number * 1000000000
        print("You entered \(number) GB")
       // print("That's \(result) Bytes")
        memsize = bytes_available
    }
    else{
        print("Why you trying to break the app?!? (╯°□°）╯︵ ┻━┻")
        exit(0)
        
    }
}

let powers: [Int32] = determine_Size(memory_capacity:memsize)
//array of 3 entries. Those entries are the powers to which we can raise
//while staying within the machines memory footprint




var test_point: Int = 0     //loop counter

var test_scope: Int = Int(powers[0]+powers[1]+powers[2])


        //What power are we raising the dimensions of the
        //square matrices we're going to create and solve
//print(powers)
//print(test_scope)




var tests: [Int] = Array(repeating: 0, count: test_scope)
                            //array of the various tests sizes we're going to
                            //run
var results: [Double] = Array(repeating: 0, count: test_scope)


while(test_point<powers[0]){
    
    //Base 2
    tests[test_point] = 2<<test_point
    
    test_point+=1
   
     }

test_point = 1

//print(tests)
tests.sort()
//print(tests)


//Base3

tests[0] = 3

while(test_point<powers[1]){
    
    tests[test_point] = 3*tests[test_point-1]
        
    test_point+=1
}
test_point = 1

//Base 10
//print(tests)
tests.sort()
//print(tests)
tests[0] = 10

while(test_point<powers[2]){
    
    tests[test_point] = 10*tests[test_point-1]
        
    test_point+=1
}

//print(tests)
tests.sort()
//print(tests)

 
 test_point+=1

// once we have all 3 types, sort them here

tests.sort()
print("Running the following tests:",tests)

test_point = 0 //reset counter
//alocate the arrays to be of maximum size:

let matrix_size: Int = tests[test_scope-1]*tests[test_scope-1]
let matrix_dimensions: Int32 = Int32(tests[test_point])
//some sort of alocation
var mat_A: [Double] = Array<Double>(repeating: 0.0, count: matrix_size)
var mat_B: [Double] = Array<Double>(repeating: 0.0, count: matrix_size)
var mat_C: [Double] = Array<Double>(repeating: 0.0, count: matrix_size)

var i = 0

print("Filling the matricies with random data, this may take a while...")

while(i<matrix_size)
{
    mat_C[i] = Double.random(in: 2.71828...3.14159)
    mat_B[i] = mat_C[i] + 1
    mat_A[i] = 2*mat_B[i]
    //mat_B[i] = Double.random(in: 2.71828...3.14159)
    //mat_A[i] = Double.random(in: 2.71828...3.14159)
    i += 1
    // THIS IS REALLY SLOW
    
}
print("finished filling matrix of size", matrix_size, "with data")
print("taking a 10 seconds to avoid SOC hot spotting, normalizing clocks etc.")
print("")
sleep(10)




repeat{
    
    let matrix_dimensions: Int32 = Int32(tests[test_point])
    
    //swift array notation is weird, not sure how much of that is me, how much
    // is the lang?
   // print("finished alocating matrix of size", matrix_size)
    
    // fill with random data
    //prefered notation seems to be mat_Z = [[TYPE]],
    //but that doesn't bound at compile time?
    
    
    //timer start
    let start = DispatchTime.now()
    

    //call accelerate
    cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, matrix_dimensions, matrix_dimensions, matrix_dimensions, 1.0, &mat_A, matrix_dimensions, &mat_B, matrix_dimensions, 1.0, &mat_C, matrix_dimensions)
                // DGEMM AKA IEEE 754 Binary64 generalized
                // matrix multiply.
    let end = DispatchTime.now()
    
    let delta:Double = Double((end.uptimeNanoseconds - start.uptimeNanoseconds))
    
    //print("took",delta, "to do nothing")
    
    let edge:Double = Double(matrix_dimensions)
    
    let Gflops:Double = Double(edge*edge*edge) / ( Double(delta))
    // convenient thing: if you're outputing in Gflops you don't have to change
    // the units of a nanosecond timer: both are 10^9 and cancel out
    
    results[test_point]=Gflops
    
    //print("Since GEMM is an N^3 algorithm, we can divide", edge,"cubed by", delta," to calculate Gflops")
    
    print("Given square matricies of dimesions =",matrix_dimensions, " machine reaches ", Gflops, "GFLOPS")
    
    //end timer, then convert time and size of matrix to Gflops

    sleep(1)
    
    
    test_point += 1
}while(test_point < test_scope)


print("Lower than you thought? Maybe consider a different kind of Apple?")
print("Up to the task? Enjoy a nice refreshing brew; you've earned it!")
print()
print("Please share the following 2 lines and your device model with the author")
print(tests)
print(results)


func determine_Size(memory_capacity: Int64)-> [Int32] {

    //use user input of memory capacity to calculate max bounds for matricies
    //
    
    var matrix_dimensions: Int64 = Int64(memory_capacity)
    
    matrix_dimensions = matrix_dimensions/8
 //   print(matrix_dimensions)
        // of 64 bits / 8 bytes
    matrix_dimensions = matrix_dimensions/3
 //   print(matrix_dimensions)
        // 3 arrays
    matrix_dimensions = Int64(Double (matrix_dimensions).squareRoot())
 //   print(matrix_dimensions)
        // from which we want the linear dimensions
    
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


