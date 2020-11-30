# variables.tf for Lambda (lambda_sqs_variables.tf)

variable stream_as_source_to_lambda_sqs2 {
    description     = "Whether Dynamo DB Stream is used as source for Lambda"
    type            = bool
}


variable "lambda_function_file_name_sqs2" {
  description = "The lambda function file name for streams processing"
}

variable "lambda_function_handler_name_sqs2" {
    description     = "Name of the Lambda handler; Python: filename.python_function; java: package.class_name"
}

variable lambda_s3_bucket_name_sqs2 {
    description             = "The S3 bucket location containing the function's deployment package."
}

variable lambda_s3_bucket_key_sqs2 {
    description             = "The S3 key of an object containing the function's deployment package"
}

variable lambda_function_source_name_sqs2 {
    description             = "A unique name for your Lambda Function Source name to transform data"
}

variable lambda_function_description_sqs2 {
    description             = "Description of what your Lambda Function does - Streams Lambda"
}

variable lambda_memory_size_mb_sqs2 {
    description             = "Amount of memory in MB your Lambda Function can use at runtime. Defaults to 128. Max 3Gb"
    default                 = 128
}

variable lambda_runtime_engine_sqs2 {
    description             = "The identifier of the function's runtime engine. e.g., nodejs12.x, java8, java11, python2.7, python3.6 etc."
}

variable lambda_timeout_secs_sqs2 {
    description             = "The amount of time your Lambda Function has to run in seconds. Defaults to 3. Max 15mins"
    default                 = 3
}

variable lambda_reserved_conc_execs_sqs2 {
    description             = "The amount of reserved concurrent executions for this lambda function. default is -1"
    default                 = -1
}

variable lambda_env_variables_sqs2 {
    description     = "Lambda Environment variables - MAP"
    type            = map(string)
    default         = {}
}