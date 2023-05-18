async function invokeAPI() {
    fetch('https://h0d6a8xs0g.execute-api.us-east-1.amazonaws.com/CloudResumeCounterTerraform').then((response) => {
        return response.json();
    })
    .then((responseJson) => {
        const message = `<p>You are visitor: ${responseJson.Attributes.Quantity.N}</p>`;
        document.getElementById("Visitors").innerHTML=message;
    })
    .catch((error) => {
        console.log(error)
        return error
    })
};

function demoText(){
    return "This is demo text";
};
invokeAPI();