using ClassLibrary4;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

var app = builder.Build();

// Configure the HTTP request pipeline.

app.UseHttpsRedirection();

app.MapGet("/add", () =>
{
    return Calculator.AddNumbers(1, 2);
});

app.Run();

