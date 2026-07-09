import inspect
import youtube_transcript_api._transcripts as ts

print("FetchedTranscript fields/methods:")
for name, member in inspect.getmembers(ts.FetchedTranscript):
    if not name.startswith("__"):
        print(f"  {name}: {type(member)}")

print("\nFetchedTranscript init signature:")
print(inspect.signature(ts.FetchedTranscript.__init__))
