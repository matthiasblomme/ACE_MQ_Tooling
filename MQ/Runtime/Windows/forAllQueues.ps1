param(
    [parameter(Mandatory=$true)][String]$qmgrName,
    [parameter(Mandatory=$true)][String]$alterString
)

$fullOutput = echo "dis ql(*)" | runmqsc $qmgrName
$alterCmd = $fullOutput | select-string -Pattern '.*QUEUE\((.*?)\).*' | % { "ALTER QL('" + $($_.matches.groups[1].value) + "') $alterString" }
foreach($line in $alterCmd) {
    write-host 'echo "' $line '" | runmqsc $qmgrName'
}