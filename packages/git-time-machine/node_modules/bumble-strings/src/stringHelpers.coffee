
_ = require('underscore')

module.exports = class StringHelpers
  
  @trim: (str) -> 
    return str.replace(/^\s+|\s+$/g, "")
  
  ###
    otherStr can also be an array of other strings
  ###
  @startsWith: (str, otherStr) ->
    otherStrings = if _.isArray(otherStr) then otherStr else [otherStr]
    for testString in otherStrings
      return true if str.slice(0, testString.length) == testString
    
    return false
  
  
  @has: (str, otherStr) ->
    str.indexOf(otherStr) != -1

  @weakValue: (str, options={}) ->
    _.defaults options,
      ignoreCase: true
      useLocale: false
      trim: true
    if options.trim
      str = @trim(str) 
    if (options.ignoreCase) 
        if (options.useLocale) 
            str = str.toLocaleLowerCase()
        else 
            str = str.toLowerCase()
    
  @weaklyEqual: (str, otherStr, options={}) ->
    return @weakValue(str, options) == @weakValue(otherStr, options)      
    
    
  @weaklyCompare: (str, otherStr, options={}) ->
    return @weakValue(str, options).localeCompare(@weakValue(otherStr, options))
    
    
  @weaklyHas: (str, otherStr) ->
    return @weakValue(str).indexOf(@weakValue(otherStr)) != -1
    
    
  @weaklyStartsWith: (str, otherStr) ->
    return @startsWith(@weakValue(str), @weakValue(otherStr))
    
    
  