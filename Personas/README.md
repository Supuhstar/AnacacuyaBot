# Personas

This folder contains some example persona modelfiles that you can use to configure the language model powering your AnacacuyaBot instance.

You're encouraged to make your own persona modelfile and store it outside this repository.


## Using a persona modelfile

The Luna Nightshade persona is the default. If you want to use any other (I'll call the example one here `Polaris Ab` in the file `polaris-Ab.modelfile`).

When you create or change the modelfile, compile it to a "model" using `ollama create`, like this:
```sh
ollama create Polaris-Ab-model -f polaris-Ab.modelfile
```

Then, set it as the model that your AnacacuyaBot instance will use:
```sh
export OLLAMA_MODEL=Polaris-Ab-model
```

I recommend storing that in some environment shell file that's automatically read in every time, along with the Telegram bot name you're using and other such environment variables.
