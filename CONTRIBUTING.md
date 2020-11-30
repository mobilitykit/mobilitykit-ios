# How to contribute

I'm really glad you're reading this, because we need volunteer developers to help this project come to fruition.

If you haven't already, come find us on [Slack](https://mobilitykit.slack.com/). We want you working on things you're excited about.

Here are some important informations:

  * You found bugs? Use the issue board here to report them
  * You have feature requests? Join Slack and discuss them with us.
  * You want to share your code? Send a pull request (details see below)

## Testing

New versions and features will be developed with TDD style.

## Submitting changes

Please send a [GitHub Pull Request](https://github.com/mobilitykit/mobilitykit-ios/pull/new/master) with a clear list of what you've done (read more about [pull requests](http://help.github.com/pull-requests/)). When you send a pull request, we will love you forever if you include tests from your TDD. We can always use more test coverage. Please follow our coding conventions (below) and make sure all of your commits are atomic (one feature per commit).

Always write a clear log message for your commits. One-line messages are fine for small changes, but bigger changes should look like this:

    $ git commit -m "A brief summary of the commit
    >
    > A paragraph describing what changed and its impact."

## Coding conventions

Start reading our code and you'll get the hang of it. We optimize for readability:

  * We use Xcode code style for the iOS project
  * We ALWAYS put spaces after list items and method parameters (`[1, 2, 3]`, not `[1,2,3]`), around operators (`x += 1`, not `x+=1`), and around hash arrows.
  * This is open source software. Consider the people who will read your code, and make it look nice for them. It's sort of like driving a car: Perhaps you love doing donuts when you're alone, but with passengers the goal is to make the ride as smooth as possible.

Thanks,
Tobias Frech
