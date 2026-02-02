## towards a better GIS system



right now we are kind of storing a database inside a database. One other main things of Terrain is it fields list (temperature, distance to ocean, coutries) and elevations. Inside of country details and hexregion we now have a way of creating smaller terrains out of larger ones.

I still very much like the terrain as an object to work with.

but if we have a database it feels like we could have much bigger maps if we store everything in a fields table by a universal hexposition and then could drop down to smaller ones when we needed to render or compute things. lets consider a fields table